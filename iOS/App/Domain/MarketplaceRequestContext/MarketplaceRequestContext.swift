//
//  MarketplaceRequestContext.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceRequestContext: Equatable {
    let pageRevision: Int
    let role: MarketplaceRole
    let environmentRevision: Int
    var identityRevision: Int = 0
}
