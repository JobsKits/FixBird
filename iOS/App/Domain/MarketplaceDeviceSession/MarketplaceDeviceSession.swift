//
//  MarketplaceDeviceSession.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceDeviceSession: Codable, Equatable {
    let id: String
    let device: MarketplaceDevice
    let authMethod: String
    let capabilities: [String]
    let createdAt: String
    let expiresAt: String
    var isCurrent: Bool? = nil
}
