//
//  MarketplaceLedgerJournal.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceLedgerJournal: Codable {
    let id: String
    let eventKey: String
    let orderId: String
    let customerId: String
    let workerId: String
    let settlementId: String
    let mode: String
    let simulated: Bool
    let kind: String
    let channel: String
    let status: String
    let amountCents: Int64
    let workerShareCents: Int64
    let platformFeeCents: Int64
    let occurredAt: String
    let actorId: String
    let reason: String
    let reversalOfId: String
    let entries: [MarketplaceLedgerEntry]
}
