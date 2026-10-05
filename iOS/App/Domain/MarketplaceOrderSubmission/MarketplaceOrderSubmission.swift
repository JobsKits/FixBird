//
//  MarketplaceOrderSubmission.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceOrderSubmission {
    private var previousAttempt: CreateRepairOrder?
    private var requestKey = UUID().uuidString

    /// 仅在实际尝试提交时记录内容；同一表单的手动重试复用键。
    mutating func key(for input: CreateRepairOrder) -> String {
        if let previousAttempt, previousAttempt != input {
            requestKey = UUID().uuidString
        }
        previousAttempt = input
        return requestKey
    }
}
