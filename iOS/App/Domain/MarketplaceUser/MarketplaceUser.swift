//
//  MarketplaceUser.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceUser: Codable, Equatable {
    let id: String
    let username: String
    let displayName: String
    let role: String

    var marketplaceRole: MarketplaceRole? {
        return MarketplaceRole(rawValue: role)
    }
}
