//
//  MarketplaceTestSupport.swift
//  RepairMarketplaceTests
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

/// 独立测试仅替换网络边界，缓存、模型和状态迁移使用真实 App 源码。
enum HTTPMethod {
    case get
    case post
    case delete
}
struct JobsValue {
    let raw: Any?

    init(_ value: Any?) {
        raw = value
    }
}
struct EmptyResponse: Decodable {
}
final class JobsRequestToken {
    func cancel() {}
}
enum MarketplaceEnvironment: String {
    case test
    static var current: Self = .test
    static var baseURLString = "http://test.example:8080"
}
final class TestMarketplaceAPI: MarketplaceAPIClient, MarketplacePrivateAssetClient {
    var response = Data("[]".utf8)
    var failure: MarketplaceRemoteFailure?
    var idempotencyKeys: [String?] = []
    var requestedPaths: [String] = []
    var requestedBodies: [[String: JobsValue]?] = []
    var requestedMethods: [HTTPMethod] = []
    var deferResponses = false
    private var pending: [() -> Void] = []

    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        role: MarketplaceRole,
        body: [String: JobsValue]?,
        idempotencyKey: String?,
        completion: @escaping (Result<Response, MarketplaceRemoteFailure>) -> Void
    ) -> JobsRequestToken? {
        idempotencyKeys.append(idempotencyKey)
        requestedPaths.append(path)
        requestedBodies.append(body)
        requestedMethods.append(method)
        let data = response
        let failure = failure
        let deliver = {
            if let failure {
                completion(.failure(failure))
            } else {
                do {
                    if Response.self == Data.self, let bytes = data as? Response {
                        completion(.success(bytes))
                    } else {
                        completion(.success(try JSONDecoder.make { _ in }.decode(Response.self, from: data)))
                    }
                } catch {
                    completion(.failure(MarketplaceRemoteFailure(kind: .unknown, statusCode: nil, detail: error.localizedDescription)))
                }
            }
        }
        if deferResponses {
            pending.append(deliver)
        } else {
            deliver()
        }
        return nil
    }

    func uploadWorkerImage(_ data: Data, completion: @escaping (Result<MarketplaceWorkerAsset, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken? {
        return send(path: "/api/v1/worker-assets", method: .post, role: .worker, body: nil, idempotencyKey: nil, completion: completion)
    }

    func flush() {
        let callbacks = pending
        pending.removeAll()
        callbacks.forEach { $0() }
    }
}
final class MarketplaceAPI {
    static let shared = TestMarketplaceAPI()
}

final class TestCacheStorage: MarketplaceCacheStorage {
    private(set) var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        return values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value as? Data
    }
}

/// 只替换系统 Keychain 边界，测试不会读写本机任何真实凭据。
final class MarketplaceKeychain: MarketplaceCredentialStorage {
    var values: [String: Data] = [:]
    var canSave = true

    func credential(for key: String) -> Data? {
        return values[key]
    }

    func saveCredential(_ data: Data, for key: String) -> Bool {
        guard canSave else {
            return false
        }
        values[key] = data
        return true
    }

    func removeCredential(for key: String) {
        values.removeValue(forKey: key)
    }
}
