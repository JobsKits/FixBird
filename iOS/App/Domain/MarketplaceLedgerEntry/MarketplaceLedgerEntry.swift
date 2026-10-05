//
//  MarketplaceLedgerEntry.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceLedgerEntry: Codable {
    let account: String
    let direction: String
    let amountCents: Int64
}
