//
//  MarketplaceDeviceStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceDeviceStore {
    static let shared = MarketplaceDeviceStore()
    private let client: MarketplaceAPIClient
    private let cache: MarketplacePrivateCache

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared, defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.client = client
        cache = MarketplacePrivateCache(defaults: defaults)
    }

    func preview(role: MarketplaceRole) -> MarketplaceOutcome<[MarketplaceDeviceSession]> {
        if let snapshot = cache.read([MarketplaceDeviceSession].self, key: "devices", role: role, demo: false) {
            return MarketplaceOutcome(value: snapshot, source: .snapshot)
        }
        return MarketplaceOutcome(value: [], source: .demo)
    }

    @discardableResult
    func fetch(role: MarketplaceRole, completion: @escaping (MarketplaceOutcome<[MarketplaceDeviceSession]>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/auth/devices", method: .get, role: role, body: nil, idempotencyKey: nil) { [weak self] (result: Result<[MarketplaceDeviceSession], MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 当前账号全部有效设备由服务端返回。
            case .success(let devices):
                self.cache.write(devices, key: "devices", role: role, demo: false)
                completion(MarketplaceOutcome(value: devices, source: .server))
            /// 不把断网误读为其他设备已经退出。
            case .failure(let failure):
                completion(MarketplaceOutcome(value: [], source: .demo, failure: failure))
            }
        }
    }

    func revoke(_ id: String, role: MarketplaceRole, completion: @escaping (Result<EmptyResponse, MarketplaceRemoteFailure>) -> Void) {
        guard id.range(of: #"^[A-Za-z0-9_-]{1,128}$"#, options: .regularExpression) != nil else {
            completion(.failure(MarketplaceRemoteFailure(kind: .rejected, statusCode: nil, detail: "设备会话编号无效。")))
            return
        }
        client.send(path: "/api/v1/auth/devices/" + id, method: .delete, role: role, body: nil, idempotencyKey: nil, completion: completion)
    }
}
