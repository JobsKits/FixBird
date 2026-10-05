//
//  JobsSplashVC.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import AVFoundation
import JobsSwiftBaseDefines
import JobsInheritance
import JobsByUIKit
import JobsCountdownButton
import JobsSwiftDSL
import JobsSwiftOpen
import SnapKit

public final class JobsSplashVC: BaseVC {
    private let countdownTimeKey = "com.BSports.countdownTimeKey"
    private let isCountdownTimeKey = "com.BSports.isCountdownTimeKey"
    private let defaultCountdownTime = 15 * 60

    public let configuration: JobsSplashConfiguration

    private var mediaTask: URLSessionTask?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var hasFinished = false
    private var hostGestureRestoration: (() -> Void)?
    private var remoteVideoNoticeTrailingConstraint: Constraint?
    private var remoteVideoNoticeCenterYConstraint: Constraint?

    private var isCountdownTime: Bool {
        get {
            UserDefaults.standard.bool(forKey: isCountdownTimeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isCountdownTimeKey)
        }
    }

    private var countdownTime: Int {
        get {
            guard isCountdownTime else {
                return effectiveCountdownSeconds
            }
            let value = UserDefaults.standard.integer(forKey: countdownTimeKey)
            return value > 0 ? value : effectiveCountdownSeconds
        }
        set {
            UserDefaults.standard.set(newValue, forKey: countdownTimeKey)
        }
    }

    private var effectiveCountdownSeconds: Int {
        max(0, configuration.countdownSeconds ?? defaultCountdownTime)
    }

    private lazy var imageView: UIImageView = {
        UIImageView.jobsMake { _ in }
            .byContentMode(configuration.contentMode)
            .byClipsToBounds()
            .byUserInteractionEnabled(true)
            .onJobsTap { [weak self] (_: UIImageView) in
                self?.perform(self?.configuration.tapAction)
            }
    }()

    private lazy var remoteVideoDownloadNoticeLabel: UILabel = {
        UILabel.jobsMake { _ in }
            .byText(JobsSplashLocalization.remoteVideoWiFiDownloadNotice(language: configuration.language))
            .byTextColor(JobsCor.white)
            .byFont(JobsFont.systemFont(ofSize: 12, weight: .medium))
            .byTextAlignment(.right)
            .byNumberOfLines(1)
            .byVisible(false)
    }()

    private lazy var skipButton: UIButton = {
        UIButton.sys()
            .byBackgroundColor(JobsCor.black.withAlphaComponent(0.45), for: .normal)
            .byTitleColor(JobsCor.white)
            .byTitleFont(JobsFont.systemFont(ofSize: 14, weight: .medium))
            .byCornerRadius(18)
            .byMasksToBounds(true)
            .byCountdown { [weak self] cfg in
                guard let self else { return }
                cfg.mode = .down(from: self.countdownTime)
                cfg.clickableWhileRunning = true
                cfg.onTapWhileRunning = { [weak self] _, _ in
                    self?.finish()
                }
                cfg.renderLegacy = { [weak self] sec, button in
                    self?.renderSkipButtonTitle(button, remainingSeconds: sec)
                }
                if #available(iOS 15.0, *) {
                    cfg.renderConfiguration = { [weak self] sec, base in
                        guard let self else { return base }
                        var config = base
                        config.title = self.skipButtonTitle(remainingSeconds: sec)
                        return config
                    }
                }
                cfg.onTick = { [weak self] _, _, sec in
                    guard let self else { return }
                    self.isCountdownTime = true
                    self.countdownTime = sec
                }
                cfg.onFinish = { [weak self] _, _ in
                    self?.finish()
                }
            }
            .onTap { [weak self] _ in
                guard let self else { return }
                if let ctrl = self.skipButton.jobsCountdownController,
                   ctrl.isRunning {
                    ctrl.config.onTapWhileRunning?(self.skipButton, ctrl.config)
                } else {
                    self.finish()
                }
            }
    }()

    public init(configuration: JobsSplashConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var canBecomeFirstResponder: Bool { true }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.byBackgroundColor(JobsCor.systemBackground)
        imageView
            .byAddTo(view) { make in
                make.edges.equalToSuperview()
            }
        skipButton
            .byVisible(configuration.isSkipButtonVisible)
            .byAddTo(view)
        remoteVideoDownloadNoticeLabel
            .byAddTo(view) { [unowned self] make in
                if let customFrame = configuration.skipButtonFrame {
                    remoteVideoNoticeTrailingConstraint = make.trailing
                        .equalTo(view.snp.leading)
                        .offset(customFrame.minX - 8)
                        .constraint
                    remoteVideoNoticeCenterYConstraint = make.centerY
                        .equalTo(view.snp.top)
                        .offset(customFrame.midY)
                        .constraint
                } else {
                    remoteVideoNoticeTrailingConstraint = make.trailing
                        .equalTo(view.snp.trailing)
                        .offset(-configuration.skipButtonInsets.right - skipButtonDynamicWidth - 8)
                        .constraint
                    remoteVideoNoticeCenterYConstraint = make.centerY
                        .equalTo(view.safeAreaLayoutGuide.snp.top)
                        .offset(configuration.skipButtonInsets.top + 18)
                        .constraint
                }
                make.leading.greaterThanOrEqualTo(view.snp.leading).offset(16)
                make.height.equalTo(36)
            }
        renderContent()
        startCountdownIfNeeded()
        refreshSkipButtonTitle()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        byGKNavBarHidden(true)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        byGKNavBarHidden(true)
        becomeFirstResponder()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.byFrame(imageView.bounds)
        if let customFrame = configuration.skipButtonFrame {
            skipButton.byFrame(customFrame)
        } else {
            skipButton.byFrame(CGRect(
                x: view.bounds.width - configuration.skipButtonInsets.right - skipButtonDynamicWidth,
                y: view.safeAreaInsets.top + configuration.skipButtonInsets.top,
                width: skipButtonDynamicWidth,
                height: 36
            ))
        }
        updateRemoteVideoNoticePosition()
    }

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        perform(configuration.shakeAction)
    }

    deinit {
        restoreHostGesturesIfNeeded()
        skipButton.countdownStop(resetUI: false)
        mediaTask?.cancel()
        player?.pause()
    }

    @MainActor
    public func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        isCountdownTime = false
        countdownTime = 0
        skipButton.countdownStop(resetUI: false)
        mediaTask?.cancel()
        player?.pause()
        restoreHostGesturesIfNeeded()
        configuration.onSkip?(self)
        let isNavigationStackMember = navigationController?.viewControllers.contains {
            $0 === self
        } == true
        if parent != nil, !isNavigationStackMember {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
        } else if presentingViewController != nil {
            dismiss(animated: false)
        } else if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: false)
        } else {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
        }
    }

    func restoreHostGesturesOnFinish(_ block: @escaping () -> Void) {
        hostGestureRestoration = block
    }

    private func renderContent() {
        switch configuration.content {
        /// 处理 .localImage 分支
        case let .localImage(name, bundle):
            imageView.byImage(UIImage(named: name, in: bundle, compatibleWith: nil))
        /// 处理 .localGIF 分支
        case let .localGIF(name, bundle):
            guard let url = resourceURL(name: name, defaultExtension: "gif", bundle: bundle),
                  let data = try? Data(contentsOf: url) else { return }
            imageView.byImage(JobsSplashGIFDecoder.image(data: data))
        /// 处理 .remoteImage 分支
        case let .remoteImage(url):
            loadRemoteImage(url)
        /// 处理 .localVideo 分支
        case let .localVideo(name, fileExtension, bundle):
            guard let url = resourceURL(name: name, defaultExtension: fileExtension, bundle: bundle) else { return }
            playVideo(url)
        /// 处理 .remoteVideo 分支
        case let .remoteVideo(url, fallbackName, fallbackFileExtension, fallbackBundle):
            loadRemoteVideo(
                url,
                fallbackName: fallbackName,
                fallbackFileExtension: fallbackFileExtension,
                fallbackBundle: fallbackBundle
            )
        }
    }

    private func loadRemoteImage(_ url: URL) {
        if let cachedURL = JobsSplashMediaCache.shared.cachedFileURL(for: url),
           let data = try? Data(contentsOf: cachedURL) {
            imageView.byImage(image(from: data, url: url))
            return
        }
        mediaTask = JobsSplashMediaCache.shared.download(url) { [weak self] result in
            guard let self, case let .success(localURL) = result,
                  let data = try? Data(contentsOf: localURL) else { return }
            self.imageView.byImage(self.image(from: data, url: url))
        }
    }

    private func loadRemoteVideo(
        _ url: URL,
        fallbackName: String?,
        fallbackFileExtension: String?,
        fallbackBundle: Bundle
    ) {
        if let cachedURL = JobsSplashMediaCache.shared.cachedFileURL(for: url) {
            remoteVideoDownloadNoticeLabel.byVisible(false)
            playVideo(cachedURL)
            return
        }
        if let fallbackName,
           let fallbackURL = resourceURL(
               name: fallbackName,
               defaultExtension: fallbackFileExtension,
               bundle: fallbackBundle
           ) {
            playVideo(fallbackURL)
        }
        remoteVideoDownloadNoticeLabel.byVisible(true)
        JobsSplashMediaCache.shared.preloadVideo(url) { [weak self] _ in
            guard let self, !self.hasFinished else { return }
            self.remoteVideoDownloadNoticeLabel.byVisible(false)
        }
    }

    private func playVideo(_ url: URL) {
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = configuration.videoGravity
        playerLayer.byFrame(imageView.bounds)
        imageView.layer.addSublayer(playerLayer)
        self.player = player
        self.playerLayer = playerLayer
        player.play()
    }

    private func image(from data: Data, url: URL) -> UIImage? {
        if url.pathExtension.lowercased() == "gif" {
            return JobsSplashGIFDecoder.image(data: data)
        };return UIImage(data: data)
    }

    private func resourceURL(name: String, defaultExtension: String?, bundle: Bundle) -> URL? {
        if name.hasPrefix("/") {
            let fileURL = URL(fileURLWithPath: name)
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        }
        let nameExtension = (name as NSString).pathExtension
        if !nameExtension.isEmpty {
            return bundle.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: nameExtension
            )
        };return bundle.url(forResource: name, withExtension: defaultExtension)
    }

    private func startCountdownIfNeeded() {
        guard configuration.countdownSeconds != nil || isCountdownTime else { return }
        let seconds = countdownTime
        guard seconds > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.finish()
            };return
        }
        isCountdownTime = true
        countdownTime = seconds
        skipButton.countdownStart()
    }

    private func refreshSkipButtonTitle() {
        renderSkipButtonTitle(skipButton, remainingSeconds: configuredRemainingSeconds)
        view.bySetNeedsLayout()
    }

    private var skipButtonDynamicWidth: CGFloat {
        let size = skipButton.sizeThatFits(CGSize(width: 160, height: 36))
        return max(64, size.width + 24)
    }

    private func updateRemoteVideoNoticePosition() {
        if let customFrame = configuration.skipButtonFrame {
            remoteVideoNoticeTrailingConstraint?.update(offset: customFrame.minX - 8)
            remoteVideoNoticeCenterYConstraint?.update(offset: customFrame.midY)
        } else {
            remoteVideoNoticeTrailingConstraint?.update(
                offset: -configuration.skipButtonInsets.right - skipButtonDynamicWidth - 8
            )
            remoteVideoNoticeCenterYConstraint?.update(
                offset: configuration.skipButtonInsets.top + 18
            )
        }
    }

    private var configuredRemainingSeconds: Int? {
        configuration.countdownSeconds == nil && !isCountdownTime ? nil : countdownTime
    }

    private func skipButtonTitle(remainingSeconds: Int?) -> String {
        JobsSplashLocalization.skipTitle(
            language: configuration.language,
            remainingSeconds: remainingSeconds
        )
    }

    private func renderSkipButtonTitle(_ button: UIButton, remainingSeconds: Int?) {
        button.byTitle(skipButtonTitle(remainingSeconds: remainingSeconds))
    }

    private func perform(_ action: JobsSplashAction?) {
        guard let action else { return }
        switch action {
        /// 处理 .open 分支
        case let .open(configuration):
            JobsOpen.shared.open(configuration, from: self)
        /// 处理 .custom 分支
        case let .custom(block):
            block(self)
        /// 处理 .none 分支
        case .none:
            break
        }
    }

    private func restoreHostGesturesIfNeeded() {
        guard let hostGestureRestoration else { return }
        self.hostGestureRestoration = nil
        hostGestureRestoration()
    }
}
