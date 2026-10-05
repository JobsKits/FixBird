//
//  MarketplaceLedgerSummary.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceLedgerSummary: Codable {
    let mode: String
    let simulated: Bool
    let scope: String
    let currency: String
    let journalCount: Int
    let collectedCents: Int64
    let workerAccruedCents: Int64
    let platformRevenueCents: Int64
    let payoutCents: Int64
    let platformFundsCents: Int64
    let workerPayableCents: Int64

    static let emptyDemo = Self(mode: "simulated", simulated: true, scope: "filtered_movements", currency: "CNY", journalCount: 0, collectedCents: 0, workerAccruedCents: 0, platformRevenueCents: 0, payoutCents: 0, platformFundsCents: 0, workerPayableCents: 0)
}
