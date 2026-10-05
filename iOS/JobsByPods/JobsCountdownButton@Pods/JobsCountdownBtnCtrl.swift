//
//  JobsCountdownBtnCtrl.swift
//  JobsCountdownButton
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftTimer
import JobsSwiftBaseDefines

// MARK: - iOS 14 及以下 UIButton 状态快照（用于 stop(resetUI: true) 复原）

#if os(iOS) || os(tvOS)
private struct JobsLegacyButtonState {
    // 只抓最常用且不会破坏你逻辑的字段；你后续如果需要更多（背景图、富文本等）可以继续往里加
    let isEnabled: Bool

    // 使用你自己的「获取UI」API 做快照（兼容 iOS15+ / iOS14- 的读取语义）
    let titleNormal: String?
    let titleSelected: String?
    let attrTitleNormal: NSAttributedString?
    let attrTitleSelected: NSAttributedString?
    let titleColorNormal: UIColor?
    let titleColorSelected: UIColor?
    let imageNormal: UIImage?
    let imageSelected: UIImage?
    let backgroundImageNormal: UIImage?
    let backgroundImageSelected: UIImage?

    init(_ button: UIButton) {
        self.isEnabled = button.jobs_effectiveState != .disabled
        self.titleNormal = button.jobs_title(for: .normal)
        self.titleSelected = button.jobs_title(for: .selected)
        self.attrTitleNormal = button.jobs_attributedTitle(for: .normal)
        self.attrTitleSelected = button.jobs_attributedTitle(for: .selected)
        self.titleColorNormal = button.jobs_titleColor(for: .normal)
        self.titleColorSelected = button.jobs_titleColor(for: .selected)
        self.imageNormal = button.jobs_foregroundImage(for: .normal)
        self.imageSelected = button.jobs_foregroundImage(for: .selected)
        self.backgroundImageNormal = button.jobs_backgroundImage(for: .normal)
        self.backgroundImageSelected = button.jobs_backgroundImage(for: .selected)
    }

    func restore(to button: UIButton) {
        button.byEnabled(isEnabled)
        // 使用你自己的「DSL」API 做复原（避免直接 setXxx 导致 iOS15+ configuration 打架）
        if let attrTitleNormal {
            button.byAttributedTitle(attrTitleNormal, for: .normal)
        } else {
            button.byTitle(titleNormal, for: .normal)
        }
        if let attrTitleSelected {
            button.byAttributedTitle(attrTitleSelected, for: .selected)
        } else {
            button.byTitle(titleSelected, for: .selected)
        }
        button
            .byTitleColor(titleColorNormal, for: .normal)
            .byTitleColor(titleColorSelected, for: .selected)
            .byImage(imageNormal, for: .normal)
            .byImage(imageSelected, for: .selected)
            .byBgImage(backgroundImageNormal, for: .normal)
            .byBgImage(backgroundImageSelected, for: .selected)
    }
}

#else
private struct JobsLegacyButtonState {
    init(_ button: UIButton) { }
    func restore(to button: UIButton) { }
}
#endif

// MARK: - 内部控制器
public final class JobsCountdownBtnCtrl {
    weak var button: UIButton?
    public var config: JobsCountdownBtnConfig
    private var timer: JobsSwiftTimerProtocol?
    public private(set) var isRunning: Bool = false
    private var current: Int = 0       // up 模式下：已走步数；down 模式下：剩余秒数

    // iOS 15+ 才有 UIButton.Configuration；为了向下兼容，这里用 Any 做存储
    private let baseConfiguration_iOS15: Any?
    // iOS 14 及以下：保存一份按钮基础状态，stop(resetUI: true) 时复原
    private let baseLegacyState: JobsLegacyButtonState

    init(button: UIButton, config: JobsCountdownBtnConfig) {
        self.button = button
        self.config = config
        self.baseLegacyState = JobsLegacyButtonState(button)
        if #available(iOS 15.0, *) {
            self.baseConfiguration_iOS15 = button.configuration ?? .plain()
        } else {
            self.baseConfiguration_iOS15 = nil
        }
        // 只是初始化，不自动开跑
        if config.renderOnInit {
            current = initialValue()
            onMainAsync { [weak self] in
                guard let self else { return }
                self.applyRender(sec: self.current ?? 0)
            }
        }
    }

    deinit {
        timer?.stop()
        timer = nil
    }
}

extension JobsCountdownBtnCtrl {
    // MARK: - 对外控制
    public func start() {
        guard let btn = button else { return }
        // 先停掉旧的
        stop(resetUI: false)
        current = initialValue()
        if config.renderOnInit {
            onMainAsync { [weak self] in
                guard let self else { return }
                self.applyRender(sec: self.current)
            }
        }
        // 不允许点击就直接禁用按钮
        if !config.clickableWhileRunning {
            btn.byEnabled(false)
        }
        let tConfig = JobsSwiftTimerConfig(
            interval: config.interval,
            repeats: true,
            tolerance: config.tolerance,
            queue: .main,
            runLoop: .main,
            runLoopMode: .common,
            pauseInBackground: true,
            autoManageAppState: true
        )
        // ✅ 新版 JobsSwiftTimer：直接 new（不再用 JobsTimerFactory.make）
        let t = JobsTimer(kind: config.timerKind, config: tConfig) { [weak self] in
            // ✅ Swift 6：handler 是 @Sendable；触碰 UIKit 统一回 MainActor
            onMainAsync(self) { vc in
                self?.onTickMainActor()
            }
        }
        timer = t
        t.start()
        isRunning = true
    }

    public func stop(resetUI: Bool = true) {
        isRunning = false
        timer?.stop()
        timer = nil
        guard let btn = button else { return }
        btn.byEnabled(true)
        if resetUI {
            if #available(iOS 15.0, *) {
                if let base = baseConfiguration_iOS15 as? UIButton.Configuration {
                    btn.byConfiguration(base)
                }
            } else {
                baseLegacyState.restore(to: btn)
            }
        }
    }

    // MARK: - 内部流程
    private func initialValue() -> Int {
        switch config.mode {
        /// 处理 .down 分支
        case .down(let from): return from
        /// 处理 .up 分支
        case .up:             return 0
        }
    }

    /// ✅ 所有 UI 更新统一在 MainActor
    @MainActor
    private func onTickMainActor() {
        guard let btn = button else {
            stop(resetUI: false)
            return
        }
        switch config.mode {
        /// 处理 .down 分支
        case .down:
            current -= 1
            let sec = max(0, current)
            applyRender(sec: sec)
            config.onTick?(btn, config, sec)
            if sec <= 0 {
                finishMainActor()
            }
        /// 处理 .up 分支
        case .up(let to):
            current += 1
            let sec = min(to, current)
            applyRender(sec: sec)
            config.onTick?(btn, config, sec)
            if sec >= to {
                finishMainActor()
            }
        }
    }

    @MainActor
    private func applyRender(sec: Int) {
        guard let btn = button else { return }
        if #available(iOS 15.0, *) {
            var cfg = btn.configuration
                ?? (baseConfiguration_iOS15 as? UIButton.Configuration)
                ?? .plain()
            // iOS 15+：走 UIButton.Configuration 渲染
            if let renderer = config.renderConfiguration {
                cfg = renderer(sec, cfg)
            }
            btn.byConfiguration(cfg)
            return
        }
        // iOS 14 及以下：走 legacy 渲染（不删你的逻辑，只是把渲染出口换到 closure）
        config.renderLegacy?(sec, btn)
    }

    @MainActor
    private func finishMainActor() {
        guard let btn = button else {
            stop(resetUI: false)
            return
        }
        stop(resetUI: true)
        config.onFinish?(btn, config)
    }
}
