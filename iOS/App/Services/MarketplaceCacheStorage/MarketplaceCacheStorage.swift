//
//  MarketplaceCacheStorage.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

protocol MarketplaceCacheStorage {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: MarketplaceCacheStorage {}
