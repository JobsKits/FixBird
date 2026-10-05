//
//  MarketplaceRemoteFailure.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceRemoteFailure: Error, Equatable {
    enum Kind: Equatable {
        case rejected
        case unavailable
        case unknown
    }

    let kind: Kind
    let statusCode: Int?
    let detail: String
    var code: String? = nil
}
