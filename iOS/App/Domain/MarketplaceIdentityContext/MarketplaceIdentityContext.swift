//
//  MarketplaceIdentityContext.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

/// 模型只查询当前身份；Keychain 与会话实现由启动入口注入。
enum MarketplaceIdentityContext {
    static var actorIDProvider: ((MarketplaceRole) -> String)?

    static func actorID(for role: MarketplaceRole) -> String {
        return actorIDProvider?(role) ?? role.demoActorID
    }
}
