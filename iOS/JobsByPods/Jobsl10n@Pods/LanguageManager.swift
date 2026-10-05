//
//  LanguageManager.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public final class LanguageManager {
    public static let shared = LanguageManager()
    public private(set) var currentLanguageCode: String
    private let userDefaultsKey = "Jobs.LanguageCode"
    /// 动态 Bundle：每次按当前 code 解析路径
    public var localizedBundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
            let b = Bundle(path: path)
        else {
            return .main
        };return b
    }

    public init() {
        currentLanguageCode = resolveLanguageCode()
    }
}

extension LanguageManager {
    /// 切换语言：更新 code → 持久化 → 发通知
    public func switchTo(_ code: String) {
        // 1) 内存态必须立刻生效（不做 guard return，避免 “已是当前值” 但 bundle 没刷新）
        currentLanguageCode = code.normalizedLanguageCode
        // 2) UserDefaults 必须写入（最高优先级覆盖旧值）
        let ud = UserDefaults.standard
        ud.set("custom", forKey: languageModeKey)   // 你现有的 mode key
        ud.set(currentLanguageCode, forKey: languageCodeKey) // 你现有的 code key
        ud.synchronize()
        // 3) 如果有 Bundle.main override（Storyboard/nib 需要），这里也要同步
        Bundle.setLanguageBundle(localizedBundle)
        // 4) 通知 UI 刷新
        NotificationCenter.default.post(name: .JobsLanguageDidChange, object: nil)
    }
    /// 跟随系统语言（清除用户手动选择）
    public func followSystemLanguage() {
        let ud = UserDefaults.standard
        ud.set("system", forKey: languageModeKey)
        ud.removeObject(forKey: languageCodeKey)
        let normalized = (Locale.preferredLanguages.first ?? "en").normalizedLanguageCode
        guard normalized != currentLanguageCode else { return }
        currentLanguageCode = normalized
        NotificationCenter.default.post(name: .JobsLanguageDidChange, object: nil)
    }
}
