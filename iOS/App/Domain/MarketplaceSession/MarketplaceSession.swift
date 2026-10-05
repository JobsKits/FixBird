//
//  MarketplaceSession.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceSession: Codable, Equatable {
    let token: String
    let expiresAt: String
    let user: MarketplaceUser
    var session: MarketplaceDeviceSession? = nil

    var isUsable: Bool {
        guard token.isEmpty == false, token.contains("\r") == false, token.contains("\n") == false,
              user.id.isEmpty == false, user.marketplaceRole != nil,
              let expiration = try? Date(expiresAt, strategy: .iso8601) else {
            return false
        }
        return expiration > Date()
    }
}
