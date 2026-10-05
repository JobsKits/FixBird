//
//  MarketplacePrivateCache.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsSwiftBlock

final class MarketplacePrivateCache {
    private struct Box<Value: Codable>: Codable {
        let value: Value
    }
    private let defaults: MarketplaceCacheStorage

    init(defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.defaults = defaults
    }

    func read<Value: Codable>(_ type: Value.Type, key: String, role: MarketplaceRole, demo: Bool) -> Value? {
        guard let data = defaults.data(forKey: cacheKey(key, role: role, demo: demo)) else {
            return nil
        }
        return (try? JSONDecoder.make { _ in }.decode(Box<Value>.self, from: data))?.value
    }

    func write<Value: Codable>(_ value: Value, key: String, role: MarketplaceRole, demo: Bool) {
        let encoder = JSONEncoder.make { _ in }
        guard let data = try? encoder.encode(Box(value: value)) else {
            return
        }
        defaults.set(data, forKey: cacheKey(key, role: role, demo: demo))
    }

    private func cacheKey(_ key: String, role: MarketplaceRole, demo: Bool) -> String {
        let scope = [MarketplaceEnvironment.current.rawValue, MarketplaceEnvironment.baseURLString, role.rawValue, role.actorID]
            .map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
        return "repair.private.v1.\(demo ? "demo" : "snapshot").\(key).\(scope)"
    }
}
