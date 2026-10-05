//
//  MarketplaceViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftBaseDefines
import JobsSwiftDSL
import JobsImageTools
import JobsNetworking
import Jobsl10n

final class MarketplaceViewController: BaseVC {
    enum Tab: CaseIterable {
        case home
        case orders
        case settings

        var title: String {
            switch self {
            /// 预约分类与师傅工作台。
            case .home:
                return "首页"
            /// 当前身份订单列表。
            case .orders:
                return "订单"
            /// 本地偏好与调试入口。
            case .settings:
                return "我的"
            }
        }
    }

    var role: MarketplaceRole = .customer
    var selectedTab: Tab = .home
    var categories = RepairCategory.all
    var dynamicViews: [UIView] = []
    var pageTokens: [JobsRequestToken] = []
    var pageRevision = 0
    var pendingOrderForm: MarketplaceOrderForm?
    var quoteForm: UIAlertController?
    var messageAlert: UIAlertController?
    var lastDemoWrite: MarketplaceOutcome<RepairOrder?>?
    var logoTokens: [JobsImageLoadToken] = []
    private var languageObserver: NSObjectProtocol?
    private var themeObserver: NSObjectProtocol?
    private var brandLogoLoadToken: JobsImageLoadToken?

    lazy var contentStack = MarketplaceUIFactory.stack(margins: UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16))
    private lazy var tabStack = UIStackView.jobsMake { stack in
        stack.byAxis(.horizontal)
            .byDistribution(.fillEqually)
            .bySpacing(8)
            .byLayoutMargins(UIEdgeInsets(top: 8, left: 12, bottom: 12, right: 12), relative: true)
    }
    lazy var connectionLabel = MarketplaceUIFactory.label("服务器状态：检测中".tr, size: 12)
        .byTextColor(JobsCor.secondaryLabel)
    private lazy var brandLogoButton = UIButton.sys()
        .byImage(UIImage.make(named: "RepairLogo"))
        .byUserInteractionEnabled(false)
    private lazy var brandTitleLabel = MarketplaceUIFactory.label("啄木鸟维修".tr, size: 25, weight: .bold)
    private lazy var brandRow = UIStackView.jobsMake { stack in
        stack.byAxis(.horizontal)
            .byAlignment(.center)
            .bySpacing(10)
            .byAddArrangedSubviews([brandLogoButton, brandTitleLabel])
    }
    private lazy var refreshButton = MarketplaceUIFactory.button("重新加载".tr) { [weak self] in
        self?.render()
    }
    private lazy var header = MarketplaceUIFactory.stack(spacing: 8, margins: UIEdgeInsets(top: 12, left: 16, bottom: 10, right: 16))
        .byAddArrangedSubviews([brandRow, connectionLabel, refreshButton])
    private lazy var scrollView = UIScrollView.jobsMake { scroll in
        scroll.byShowsVerticalScrollIndicator(false)
            .byKeyboardDismissMode(.onDrag)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        role = MarketplaceSessionCenter.shared.currentRole ?? role
        jobsSetupGKNav(title: "啄木鸟维修".tr)
        view.byBackgroundColor(JobsCor.systemGroupedBackground)
        buildLayout()
        observePreferences()
        render()
    }

    deinit {
        pageTokens.forEach { token in
            token.cancel()
        }
        brandLogoLoadToken?.cancel()
        logoTokens.forEach { token in
            token.cancel()
        }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    private func buildLayout() {
        header.byAddTo(view) { [unowned self] make in
            if self.view.jobs_hasVisibleTopBar() {
                make.top.equalTo(self.gk_navigationBar.snp.bottom)
            } else {
                make.top.equalTo(self.view.safeAreaLayoutGuide)
            }
            make.leading.trailing.equalTo(self.view.safeAreaLayoutGuide)
        }
        brandLogoButton.snp.makeConstraints { make in
            make.size.equalTo(44)
        }
        tabStack.byAddTo(view) { [unowned self] make in
            make.leading.trailing.bottom.equalTo(self.view.safeAreaLayoutGuide)
        }
        scrollView.byAddTo(view) { [unowned self] make in
            make.top.equalTo(self.header.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.tabStack.snp.top)
        }
        contentStack.byAddTo(scrollView) { [unowned self] make in
            make.edges.equalTo(self.scrollView.contentLayoutGuide)
            make.width.equalTo(self.scrollView.frameLayoutGuide)
        }
        brandLogoLoadToken = loadLogo(into: brandLogoButton)
    }

    private func observePreferences() {
        languageObserver = NotificationCenter.default.addObserver(forName: .JobsLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
            self.jobsSetupGKNav(title: "啄木鸟维修".tr)
            self.brandTitleLabel.byText("啄木鸟维修".tr)
            self.refreshButton.byTitle("重新加载".tr)
            self.pendingOrderForm = nil
            self.render()
        }
        themeObserver = NotificationCenter.default.addObserver(forName: .JobsThemeDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
            self.view.byBackgroundColor(JobsCor.systemGroupedBackground)
            self.render()
        }
    }

    func render() {
        pageRevision += 1
        pageTokens.forEach { token in
            token.cancel()
        }
        pageTokens.removeAll()
        logoTokens.forEach { token in
            token.cancel()
        }
        logoTokens.removeAll()
        contentStack.byRemoveAllArrangedSubviews()
        tabStack.byRemoveAllArrangedSubviews()
        dynamicViews.removeAll()
        guard let activeRole = MarketplaceSessionCenter.shared.currentRole else {
            return
        }
        role = activeRole
        Tab.allCases.forEach { candidate in
            let button = keep(MarketplaceUIFactory.button(candidate.title.tr, selected: candidate == selectedTab) { [weak self] in
                self?.selectedTab = candidate
                self?.render()
            })
            tabStack.byAddArrangedSubview(button)
        }
        switch selectedTab {
        /// 首屏样例并请求服务端。
        case .home:
            renderHome()
        /// 用户或师傅订单。
        case .orders:
            renderOrders()
        /// 本地偏好。
        case .settings:
            renderSettings()
        }
        TRBind.consumeMarkerIfNeeded()
    }

    var requestContext: MarketplaceRequestContext {
        return MarketplaceRequestContext(pageRevision: pageRevision, role: role, environmentRevision: MarketplaceEnvironment.revision, identityRevision: MarketplaceSessionCenter.shared.revision)
    }

    func retainToken(_ token: JobsRequestToken?) {
        if let token {
            pageTokens.append(token)
        }
    }

    func keep<View: UIView>(_ view: View) -> View {
        dynamicViews.append(view)
        return view
    }
}
