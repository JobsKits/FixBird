//
//  MarketplaceLedgerStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceLedgerStore {
    static let shared = MarketplaceLedgerStore()
    private let client: MarketplaceAPIClient
    private let cache: MarketplacePrivateCache

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared, defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.client = client
        cache = MarketplacePrivateCache(defaults: defaults)
    }

    func previewSummary(role: MarketplaceRole) -> MarketplaceOutcome<MarketplaceLedgerSummary> {
        if let snapshot = cache.read(MarketplaceLedgerSummary.self, key: "ledger-summary", role: role, demo: false) {
            return MarketplaceOutcome(value: snapshot, source: .snapshot)
        }
        return MarketplaceOutcome(value: .emptyDemo, source: .demo)
    }

    func previewJournals(role: MarketplaceRole) -> MarketplaceOutcome<[MarketplaceLedgerJournal]> {
        if let snapshot = cache.read([MarketplaceLedgerJournal].self, key: "ledger-journals", role: role, demo: false) {
            return MarketplaceOutcome(value: snapshot, source: .snapshot)
        }
        return MarketplaceOutcome(value: [], source: .demo)
    }

    @discardableResult
    func summary(role: MarketplaceRole, completion: @escaping (MarketplaceOutcome<MarketplaceLedgerSummary>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/ledger/summary", method: .get, role: role, body: nil, idempotencyKey: nil) { [weak self] (result: Result<MarketplaceLedgerSummary, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 服务器确认的模拟台账仍不是银行余额。
            case .success(let summary):
                self.cache.write(summary, key: "ledger-summary", role: role, demo: false)
                completion(MarketplaceOutcome(value: summary, source: .server))
            /// 独立本地空账务，不复制真实快照伪装确认。
            case .failure(let failure):
                completion(MarketplaceOutcome(value: .emptyDemo, source: .demo, failure: failure))
            }
        }
    }

    @discardableResult
    func journals(role: MarketplaceRole, completion: @escaping (MarketplaceOutcome<[MarketplaceLedgerJournal]>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/ledger/journals?limit=200", method: .get, role: role, body: nil, idempotencyKey: nil) { [weak self] (result: Result<[MarketplaceLedgerJournal], MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 空数组也会清理旧流水快照。
            case .success(let journals):
                self.cache.write(journals, key: "ledger-journals", role: role, demo: false)
                completion(MarketplaceOutcome(value: journals, source: .server))
            /// 不把服务失败解释为真实账务归零。
            case .failure(let failure):
                completion(MarketplaceOutcome(value: [], source: .demo, failure: failure))
            }
        }
    }
}
