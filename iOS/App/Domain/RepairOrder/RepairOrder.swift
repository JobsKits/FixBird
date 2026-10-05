//
//  RepairOrder.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct RepairOrder: Codable, Identifiable {
    var id: String
    var customerId: String
    var workerId: String
    var category: String
    var equipment: String
    var issue: String
    var address: String
    var scheduledAt: String
    var status: MarketplaceOrderStatus
    var paymentStatus: String
    var quotedAmountCents: Int64
    var platformFeeCents: Int64
    var workerShareCents: Int64
    var createdAt: String
    var updatedAt: String
    /// 仅本地演示副本使用；服务端快照不写入此关联。
    var demoSourceID: String? = nil

    var quoteText: String {
        guard quotedAmountCents > 0 else {
            return "待师傅检测后报价"
        }
        return String(format: "¥%.2f", Double(quotedAmountCents) / 100)
    }
}
