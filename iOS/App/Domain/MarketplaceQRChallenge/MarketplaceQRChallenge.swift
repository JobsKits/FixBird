//
//  MarketplaceQRChallenge.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceQRChallenge: Decodable {
    let id: String
    let device: MarketplaceDevice
    let expiresAt: String
    let status: String

    var mayConfirm: Bool {
        guard status == "pending", let expiration = try? Date(expiresAt, strategy: .iso8601) else {
            return false
        }
        return expiration > Date()
    }
}
