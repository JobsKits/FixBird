//
//  UISceneConfiguration+Make.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit

/// 宿主补齐当前 Jobs 基座尚未提供的 Scene 带参创建入口。
extension UISceneConfiguration {
    static func make(name: String, sessionRole: UISceneSession.Role) -> UISceneConfiguration {
        return UISceneConfiguration(name: name, sessionRole: sessionRole)
    }

    @discardableResult
    func byDelegateClass(_ delegate: AnyClass) -> Self {
        delegateClass = delegate
        return self
    }
}
