//
//  MarketplaceOrderStatus.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

enum MarketplaceOrderStatus: String, Codable, Equatable {
    case pendingWorker = "pending_worker"
    case accepted
    case arrived
    case quotePending = "quote_pending"
    case inService = "in_service"
    case awaitingPayment = "awaiting_payment"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        /// 订单状态的本地化键。
        case .pendingWorker:
            return "待师傅接单"
        /// 订单状态的本地化键。
        case .accepted:
            return "师傅已接单"
        /// 订单状态的本地化键。
        case .arrived:
            return "师傅已到场"
        /// 订单状态的本地化键。
        case .quotePending:
            return "报价待确认"
        /// 订单状态的本地化键。
        case .inService:
            return "维修中"
        /// 订单状态的本地化键。
        case .awaitingPayment:
            return "待收款"
        /// 订单状态的本地化键。
        case .completed:
            return "已完成"
        /// 订单状态的本地化键。
        case .cancelled:
            return "已取消"
        }
    }
}

