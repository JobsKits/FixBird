//
//  JobsOpenWebViewController.swift
//  JobsSwiftOpen
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit
import JobsInheritance
import JobsByUIKit
import GKNavigationBarSwift
import SnapKit

public final class JobsOpenWebViewController: BaseVC {
    private let url: URL
    private let pageTitle: String?

    private lazy var backButton: UIButton = {
        UIButton.sys()
            .byFrame(CGRect(x: 0, y: 0, width: 64, height: 44))
            .byTitle("‹ 返回", for: .normal)
            .byContentHorizontalAlignment(.left)
            .onTap { [weak self] _ in
                self?.handleBack()
            }
    }()

    private lazy var webView: WKWebView = {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView
            .byNavigationDelegate(self)
            .byAllowsBackForwardNavigationGestures(true)
        return webView
    }()

    public init(url: URL, pageTitle: String? = nil) {
        self.url = url
        self.pageTitle = pageTitle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = pageTitle ?? url.host
        jobsSetupGKNav(title: title ?? "网页", leftButton: backButton)
        webView.byAddTo(view)
        webView.snp.makeConstraints { make in
            make.top.equalTo(gk_navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        webView.load(URLRequest(url: url))
    }

    private func handleBack() {
        if webView.canGoBack {
            webView.goBack()
        } else if let navigationController,
                  navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
        } else if let navigationController,
                  navigationController.presentingViewController != nil {
            navigationController.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension JobsOpenWebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard pageTitle == nil else { return }
        title = webView.title ?? url.host
        gk_navTitle = title ?? "网页"
    }
}
