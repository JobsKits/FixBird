//
//  JobsOpen.swift
//  JobsSwiftOpen
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit

public final class JobsOpen: NSObject {
    public static let shared = JobsOpen()

    @MainActor
    public func open(
        _ configuration: JobsOpenConfiguration = JobsOpenConfiguration(),
        from sourceViewController: UIViewController? = nil
    ) {
        switch configuration.mode {
        /// 处理 .inApp 分支
        case .inApp:
            openInsideApp(configuration, from: sourceViewController)
        /// 处理 .externalBrowser 分支
        case .externalBrowser:
            openInExternalBrowser(configuration)
        }
    }

    @MainActor
    private func openInsideApp(
        _ configuration: JobsOpenConfiguration,
        from sourceViewController: UIViewController?
    ) {
        let source = sourceViewController ?? topViewController()
        guard let source else {
            configuration.completion?(false)
            return
        }
        let webViewController = JobsOpenWebViewController(
            url: configuration.url,
            pageTitle: configuration.title
        )
        if let navigationController = source.navigationController {
            navigationController.pushViewController(webViewController, animated: configuration.animated)
        } else {
            let navigationController = UINavigationController(rootViewController: webViewController)
            navigationController.byModalPresentationStyle(.fullScreen)
            source.present(navigationController, animated: configuration.animated)
        }
        configuration.completion?(true)
    }

    @MainActor
    private func openInExternalBrowser(_ configuration: JobsOpenConfiguration) {
        guard UIApplication.shared.canOpenURL(configuration.url) else {
            configuration.completion?(false)
            return
        }
        UIApplication.shared.open(
            configuration.url,
            options: [:],
            completionHandler: configuration.completion
        )
    }
}
