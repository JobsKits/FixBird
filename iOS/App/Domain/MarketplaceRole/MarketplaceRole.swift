//
//  MarketplaceRole.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

enum MarketplaceRole: String, CaseIterable, Equatable {
    case customer
    case worker

    var actorID: String {
        return MarketplaceIdentityContext.actorID(for: self)
    }

    var demoActorID: String {
        switch self {
        /// 演示角色对应的身份与名称。
        case .customer:
            return "customer-demo"
        /// 演示角色对应的身份与名称。
        case .worker:
            return "worker-demo"
        }
    }

    var displayName: String {
        switch self {
        /// 演示角色对应的身份与名称。
        case .customer:
            return "我是用户"
        /// 演示角色对应的身份与名称。
        case .worker:
            return "我是师傅"
        }
    }
}
