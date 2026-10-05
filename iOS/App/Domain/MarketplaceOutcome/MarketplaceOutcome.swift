//
//  MarketplaceOutcome.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceOutcome<Value> {
    enum Source {
        case server
        case snapshot
        case demo
    }

    let value: Value
    let source: Source
    var failure: MarketplaceRemoteFailure?

    var isOnline: Bool {
        return source == .server
    }
}
