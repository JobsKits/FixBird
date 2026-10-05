//
//  MarketplaceAPI.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceAPI: MarketplaceAPIClient, MarketplacePrivateAssetClient {
    static let shared = MarketplaceAPI()

    /// JobsNetworking 的网络回调弱持有 Agent，宿主需保持请求期间的生命周期。
    private var activeAgents: [UUID: JobsDefaultAgent] = [:]

    var baseURLString: String {
        return MarketplaceEnvironment.baseURLString
    }

    @discardableResult
    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        role: MarketplaceRole,
        body: [String: JobsValue]? = nil,
        idempotencyKey: String? = nil,
        completion: @escaping (Result<Response, MarketplaceRemoteFailure>) -> Void
    ) -> JobsRequestToken? {
        guard let normalized = MarketplaceEnvironment.normalizedBaseURL(baseURLString),
              let baseURL = URL(string: normalized) else {
            completion(.failure(MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: "API URL is not configured")))
            return nil
        }
        let revision = MarketplaceEnvironment.revision
        let identityRevision = MarketplaceSessionCenter.shared.revision
        let bearer = authenticationToken(for: path)
        let config = JobsRequestConfig(
            baseURL: baseURL,
            timeout: 2,
            version: "v1",
            userScope: role.actorID,
            defaultRetryPolicy: JobsRetryPolicy(maxRetries: 0, initialDelay: 0, multiplier: 1),
            envelopeStrategy: .none
        )
        let agent = JobsDefaultAgent(config: config)
        let requestID = UUID()
        activeAgents[requestID] = agent
        var headers = headers(for: role, token: bearer)
        if let idempotencyKey {
            headers["Idempotency-Key"] = idempotencyKey
        }
        let request = JobsRequest(
            path: path,
            method: method,
            body: body,
            headers: headers,
            allowsEmptyResponse: path == "/api/v1/auth/logout" || (method == .delete && path.hasPrefix("/api/v1/auth/devices/"))
        )
        return agent.send(request, as: Response.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.activeAgents.removeValue(forKey: requestID)
                /// 切换环境后，旧请求不能继续写缓存或触发旧页面操作。
                guard revision == MarketplaceEnvironment.revision,
                      path == "/api/v1/auth/logout" || identityRevision == MarketplaceSessionCenter.shared.revision else {
                    return
                }
                let mapped = result.mapError { Self.failure(from: $0, isWrite: method != .get) }
                completion(mapped)
                if case .failure(let failure) = mapped, failure.statusCode == 401, let bearer {
                    MarketplaceSessionCenter.shared.invalidate(token: bearer)
                }
            }
        }
    }

    @discardableResult
    func uploadWorkerImage(_ data: Data, completion: @escaping (Result<MarketplaceWorkerAsset, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken? {
        guard data.isEmpty == false, data.count <= 2 * 1024 * 1024 else {
            completion(.failure(MarketplaceRemoteFailure(kind: .rejected, statusCode: nil, detail: "图片须压缩到2MiB以内。")))
            return nil
        }
        guard let normalized = MarketplaceEnvironment.normalizedBaseURL(baseURLString), let baseURL = URL(string: normalized) else {
            completion(.failure(MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: "API URL is not configured")))
            return nil
        }
        let revision = MarketplaceEnvironment.revision
        let identityRevision = MarketplaceSessionCenter.shared.revision
        let bearer = authenticationToken(for: "/api/v1/worker-assets")
        let config = JobsRequestConfig(baseURL: baseURL, timeout: 8, version: "v1", userScope: MarketplaceRole.worker.actorID, defaultRetryPolicy: JobsRetryPolicy(maxRetries: 0, initialDelay: 0, multiplier: 1), envelopeStrategy: .none)
        let agent = JobsDefaultAgent(config: config)
        let requestID = UUID()
        activeAgents[requestID] = agent
        let upload = JobsUploadRequest(path: "/api/v1/worker-assets", files: [.data(data: data, name: "file", fileName: "qualification.jpg", mimeType: "image/jpeg")], headers: headers(for: .worker, token: bearer), timeout: 8)
        return agent.upload(upload, as: MarketplaceWorkerAsset.self) { [weak self] result in
            DispatchQueue.main.async {
                self?.activeAgents.removeValue(forKey: requestID)
                guard revision == MarketplaceEnvironment.revision, identityRevision == MarketplaceSessionCenter.shared.revision else {
                    return
                }
                let mapped = result.mapError { Self.failure(from: $0, isWrite: true) }
                completion(mapped)
                if case .failure(let failure) = mapped, failure.statusCode == 401, let bearer {
                    MarketplaceSessionCenter.shared.invalidate(token: bearer)
                }
            }
        }
    }

    private func authenticationToken(for path: String) -> String? {
        guard path != "/api/v1/auth/login", path != "/api/v1/auth/register" else {
            return nil
        }
        return MarketplaceSessionCenter.shared.current?.token
    }

    private func headers(for role: MarketplaceRole, token: String?) -> [String: String] {
        if let token {
            return ["Authorization": "Bearer " + token]
        }
        /// 旧订单演示身份仅供演示 API；私有接口由服务端拒绝无 Bearer 请求。
        return ["X-Actor-Role": role.rawValue, "X-Actor-ID": role.actorID]
    }

    private static func failure(from error: JobsError, isWrite: Bool) -> MarketplaceRemoteFailure {
        switch error {
        /// 4xx 明确拒绝，408 可能已执行，必须保留结果未知。
        case let .http(code, data), let .server(code, data):
            let payload = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let detail = payload?["error"] as? String ?? payload?["message"] as? String
            let kind: MarketplaceRemoteFailure.Kind = (400...499).contains(code) && code != 408 ? .rejected : (isWrite ? .unknown : .unavailable)
            return MarketplaceRemoteFailure(kind: kind, statusCode: code, detail: detail ?? "HTTP \(code)", code: payload?["code"] as? String)
        /// 业务拒绝保留原因。
        case let .business(code, message, _):
            return MarketplaceRemoteFailure(kind: .rejected, statusCode: code, detail: message)
        /// 地址未配置或请求未发出。
        case let .invalidRequest(reason):
            return MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: reason)
        /// 写响应丢失、解码失败或取消时不推断服务端未执行。
        default:
            return MarketplaceRemoteFailure(kind: isWrite ? .unknown : .unavailable, statusCode: nil, detail: error.localizedDescription)
        }
    }
}
