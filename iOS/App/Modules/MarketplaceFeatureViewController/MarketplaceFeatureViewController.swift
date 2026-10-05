//
//  MarketplaceFeatureViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines
import JobsNetworking
import JobsInheritance
import Jobsl10n

/// 账号、审核、账务页面共用布局与迟到回调保护，业务分别由独立页面托管。
class MarketplaceFeatureViewController: BaseVC {
    var screenTitle: String {
        return "我的账号"
    }
    var activeRole: MarketplaceRole {
        return MarketplaceSessionCenter.shared.currentRole ?? .customer
    }
    var dynamicViews: [UIView] = []
    var requestTokens: [JobsRequestToken] = []
    var formAlert: UIAlertController?
    var messageAlert: UIAlertController?
    private var pageRevision = 0
    private var languageObserver: NSObjectProtocol?
    private var themeObserver: NSObjectProtocol?
    lazy var contentStack = MarketplaceUIFactory.stack(spacing: 12, margins: UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16))
    private lazy var scrollView = UIScrollView.jobsMake { scroll in
        scroll.byKeyboardDismissMode(.onDrag)
    }
    private lazy var reloadButton = MarketplaceUIFactory.button("重新加载".tr) { [weak self] in
        self?.reloadPage()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: screenTitle.tr)
        view.byBackgroundColor(JobsCor.systemGroupedBackground)
        reloadButton.byAddTo(view) { [unowned self] make in
            if self.view.jobs_hasVisibleTopBar() {
                make.top.equalTo(self.gk_navigationBar.snp.bottom).offset(8)
            } else {
                make.top.equalTo(self.view.safeAreaLayoutGuide).offset(8)
            }
            make.leading.trailing.equalToSuperview().inset(16)
        }
        scrollView.byAddTo(view) { [unowned self] make in
            make.top.equalTo(self.reloadButton.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalTo(self.view.safeAreaLayoutGuide)
        }
        contentStack.byAddTo(scrollView) { [unowned self] make in
            make.edges.equalTo(self.scrollView.contentLayoutGuide)
            make.width.equalTo(self.scrollView.frameLayoutGuide)
        }
        languageObserver = NotificationCenter.default.addObserver(forName: .JobsLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
            self.jobsSetupGKNav(title: self.screenTitle.tr)
            self.reloadPage()
        }
        themeObserver = NotificationCenter.default.addObserver(forName: .JobsThemeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.view.byBackgroundColor(JobsCor.systemGroupedBackground)
            self?.reloadPage()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadPage()
    }

    deinit {
        requestTokens.forEach { $0.cancel() }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    var context: MarketplaceRequestContext {
        return MarketplaceRequestContext(pageRevision: pageRevision, role: activeRole, environmentRevision: MarketplaceEnvironment.revision, identityRevision: MarketplaceSessionCenter.shared.revision)
    }

    func reloadPage() {
        pageRevision += 1
        requestTokens.forEach { $0.cancel() }
        requestTokens.removeAll()
        contentStack.byRemoveAllArrangedSubviews()
        dynamicViews.removeAll()
        drawPage()
        TRBind.consumeMarkerIfNeeded()
    }

    func drawPage() {}

    func keep<View: UIView>(_ view: View) -> View {
        dynamicViews.append(view)
        return view
    }

    func retain(_ token: JobsRequestToken?) {
        if let token {
            requestTokens.append(token)
        }
    }

    func addInfo(_ text: String, to stack: UIStackView? = nil) {
        (stack ?? contentStack).byAddArrangedSubview(keep(MarketplaceUIFactory.label(text)))
    }

    func addButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        contentStack.byAddArrangedSubview(keep(MarketplaceUIFactory.button(title, action: action).byEnabled(enabled)))
    }

    func addEmpty(_ title: String, to stack: UIStackView? = nil) {
        let button = keep(JobsEmptyAuto.Config.defaultProvider()
            .byTitle(title)
            .bySubTitle("点此重新加载。".tr)
            .byImage(UIImage.make(named: "RepairLogo"))
            .onTap { [weak self] _ in
                self?.reloadPage()
            })
        (stack ?? contentStack).byAddArrangedSubview(button)
    }

    func sourceText<Value>(_ outcome: MarketplaceOutcome<Value>) -> String {
        switch outcome.source {
        /// 当前成功响应。
        case .server:
            return "服务端已确认。".tr
        /// 缓存不能代表本次操作确认。
        case .snapshot:
            return "正在请求服务端；先显示上次快照".tr
        /// 所有失败均显式标明独立演示。
        case .demo:
            if let failure = outcome.failure {
                return "仅本地演示，未获服务端确认。".tr + "\n" + failure.detail.tr
            }
            return "仅本地演示，未获服务端确认。".tr
        }
    }

    func showMessage(_ message: String) {
        messageAlert = UIAlertController.makeAlert("提示".tr, message).byAddOK("知道了".tr)
        let expected = context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.context == expected, self.viewIfLoaded?.window != nil, self.presentedViewController == nil else {
                return
            }
            self.messageAlert?.byPresent(self, animated: true)
        }
    }
}
