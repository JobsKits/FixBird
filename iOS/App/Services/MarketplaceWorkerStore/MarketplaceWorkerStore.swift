//
//  MarketplaceWorkerStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceWorkerStore {
    static let shared = MarketplaceWorkerStore()
    private let client: MarketplaceAPIClient
    private let assets: MarketplacePrivateAssetClient
    private let cache: MarketplacePrivateCache

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared, assets: MarketplacePrivateAssetClient = MarketplaceAPI.shared, defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.client = client
        self.assets = assets
        cache = MarketplacePrivateCache(defaults: defaults)
    }

    func preview() -> MarketplaceOutcome<MarketplaceWorkerApplication?> {
        if let snapshot = cache.read(MarketplaceWorkerApplication?.self, key: "application", role: .worker, demo: false) {
            return MarketplaceOutcome(value: snapshot, source: .snapshot)
        }
        return MarketplaceOutcome(value: cache.read(MarketplaceWorkerApplication.self, key: "application", role: .worker, demo: true), source: .demo)
    }

    @discardableResult
    func fetch(completion: @escaping (MarketplaceOutcome<MarketplaceWorkerApplication?>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/workers/me/application", method: .get, role: .worker, body: nil, idempotencyKey: nil) { [weak self] (result: Result<MarketplaceWorkerApplication, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 审核状态只读取服务端或上次成功快照。
            case .success(let application):
                self.cache.write(Optional(application), key: "application", role: .worker, demo: false)
                completion(MarketplaceOutcome(value: application, source: .server))
            /// 未申请是正常空态；其它失败保留独立演示。
            case .failure(let failure):
                if failure.statusCode == 404, failure.code == "not_found" {
                    self.cache.write(Optional<MarketplaceWorkerApplication>.none, key: "application", role: .worker, demo: false)
                    completion(MarketplaceOutcome(value: nil, source: .server))
                } else {
                    completion(MarketplaceOutcome(value: self.cache.read(MarketplaceWorkerApplication.self, key: "application", role: .worker, demo: true), source: .demo, failure: failure))
                }
            }
        }
    }

    func submit(_ draft: MarketplaceWorkerDraft, completion: @escaping (MarketplaceOutcome<MarketplaceWorkerApplication?>) -> Void) {
        let body: [String: JobsValue] = ["displayName": JobsValue(draft.displayName), "contactPhone": JobsValue(draft.contactPhone), "serviceAreas": JobsValue(draft.serviceAreas), "skills": JobsValue(draft.skills), "bio": JobsValue(draft.bio), "assetIds": JobsValue(draft.assetIds), "expectedRevision": JobsValue(draft.expectedRevision)]
        client.send(path: "/api/v1/workers/me/application", method: .post, role: .worker, body: body, idempotencyKey: nil) { [weak self] (result: Result<MarketplaceWorkerApplication, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 成功后服务端 revision 与待审核状态为准。
            case .success(let application):
                self.cache.write(Optional(application), key: "application", role: .worker, demo: false)
                completion(MarketplaceOutcome(value: application, source: .server))
            /// 本地保存只能演示待审核，不能生成审核通过。
            case .failure(let failure):
                var demo = MarketplaceWorkerApplication.localDraft(actorID: MarketplaceRole.worker.actorID)
                demo.displayName = draft.displayName
                demo.contactPhone = draft.contactPhone
                demo.serviceAreas = draft.serviceAreas
                demo.skills = draft.skills
                demo.bio = draft.bio
                demo.assetIds = draft.assetIds
                demo.revision = draft.expectedRevision
                demo.updatedAt = Date().ISO8601Format()
                self.cache.write(demo, key: "application", role: .worker, demo: true)
                completion(MarketplaceOutcome(value: demo, source: .demo, failure: failure))
            }
        }
    }

    @discardableResult
    func upload(_ data: Data, completion: @escaping (MarketplaceOutcome<MarketplaceWorkerAsset?>) -> Void) -> JobsRequestToken? {
        return assets.uploadWorkerImage(data) { result in
            switch result {
            /// 私有 ID 不包含公开图片地址。
            case .success(let asset):
                completion(MarketplaceOutcome(value: asset, source: .server))
            /// 失败保留当前页图片体验，演示 ID 不能代表服务器附件。
            case .failure(let failure):
                let asset = MarketplaceWorkerAsset(id: "demo-asset-" + UUID().uuidString, mimeType: "image/jpeg", sizeBytes: data.count, createdAt: Date().ISO8601Format())
                completion(MarketplaceOutcome(value: asset, source: .demo, failure: failure))
            }
        }
    }

    @discardableResult
    func image(assetID: String, completion: @escaping (Result<Data, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken? {
        guard assetID.hasPrefix("demo-") == false,
              assetID.range(of: #"^[A-Za-z0-9_-]{1,128}$"#, options: .regularExpression) != nil else {
            completion(.failure(MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: "演示图片仅保留在当前页，请重新选择。")))
            return nil
        }
        return client.send(path: "/api/v1/worker-assets/" + assetID, method: .get, role: .worker, body: nil, idempotencyKey: nil, completion: completion)
    }
}
