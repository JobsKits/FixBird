//
//  AppDelegate.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsSwiftBaseDefines
import JobsSwiftDSL
import Jobsl10n

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        do {
            try JobsThemeCenter.shared.configure(resource: "JobsThemeResources")
        } catch {
            NSLog("JobsTheme 配置失败：%@", error.localizedDescription)
        }
        TRLang.bundleProvider = { LanguageManager.shared.localizedBundle }
        TRLang.localeCodeProvider = { LanguageManager.shared.currentLanguageCode }
        MarketplaceSessionCenter.shared.configureIdentityProvider()
        #if DEBUG
        MarketplaceDebugPanel.start()
        #endif
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration.make(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
            .byDelegateClass(SceneDelegate.self)
    }
}
