//
//  SceneDelegate.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsSwiftDSL
import JobsSwiftSplash
import Jobsl10n

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var sessionObserver: NSObjectProtocol?
    #if DEBUG
    private var environmentObserver: NSObjectProtocol?
    #endif

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let rootViewController = UINavigationController.jobsMake { navigation in
            navigation.byViewControllers([self.entryController()])
        }
        window = UIWindow.jobsMake(scene: windowScene, root: rootViewController)
        installSessionObserver()

        #if DEBUG
        installEnvironmentObserver()
        #endif

        guard JobsSplashPreferences.isEnabledForNextLaunch else {
            return
        }
        JobsSplashPresenter.show(
            over: rootViewController,
            configuration: JobsSplashConfiguration(
                content: .localImage(name: "RepairSplash")
            )
                .byCountdownSeconds(2)
                .byLanguage(.code(LanguageManager.shared.currentLanguageCode))
                .bySkipButtonVisible(true)
                .byContentMode(.scaleAspectFit)
        )
    }

    private func entryController() -> UIViewController {
        guard MarketplaceSessionCenter.shared.currentRole != nil else {
            return MarketplaceAccountViewController()
        }
        return MarketplaceViewController()
    }

    private func installSessionObserver() {
        sessionObserver = NotificationCenter.default.addObserver(forName: MarketplaceSessionCenter.didChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
            self.window?.byRootViewController(UINavigationController.jobsMake { navigation in
                navigation.byViewControllers([self.entryController()])
            })
                .byMakeKeyAndVisible()
        }
    }

    deinit {
        if let sessionObserver {
            NotificationCenter.default.removeObserver(sessionObserver)
        }
    }
    #if DEBUG
    private func installEnvironmentObserver() {
        environmentObserver = NotificationCenter.default.addObserver(
            forName: MarketplaceEnvironment.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            /// 环境切换重建业务页面，关闭旧环境的详情和编辑表单。
            self?.window?.byRootViewController(UINavigationController.jobsMake { navigation in
                navigation.byViewControllers([self?.entryController() ?? MarketplaceAccountViewController()])
            })
                .byMakeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let environmentObserver {
            NotificationCenter.default.removeObserver(environmentObserver)
        }
        environmentObserver = nil
    }
    #endif

}
