//
//  MarketplaceQRStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceQRStore {
    static let shared = MarketplaceQRStore()
    private let client: MarketplaceAPIClient
    struct Decision: Decodable {
        let status: String
    }

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared) {
        self.client = client
    }

    @discardableResult
    func inspect(_ login: MarketplaceQRLogin, role: MarketplaceRole, completion: @escaping (Result<MarketplaceQRChallenge, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/auth/qr/challenges/" + login.challengeID + "/inspect", method: .post, role: role, body: ["approvalCode": JobsValue(login.approvalCode)], idempotencyKey: nil) { (result: Result<MarketplaceQRChallenge, MarketplaceRemoteFailure>) in
            if case .success(let challenge) = result, challenge.id != login.challengeID || challenge.device.kind != "desktop" {
                completion(.failure(MarketplaceRemoteFailure(kind: .unknown, statusCode: nil, detail: "扫码设备信息不匹配，请重新扫描。")))
                return
            }
            completion(result)
        }
    }

    func decide(_ login: MarketplaceQRLogin, approve: Bool, role: MarketplaceRole, completion: @escaping (Result<Decision, MarketplaceRemoteFailure>) -> Void) {
        let body = ["approvalCode": JobsValue(login.approvalCode), "decision": JobsValue(approve ? "approve" : "reject")]
        client.send(path: "/api/v1/auth/qr/challenges/" + login.challengeID + "/approve", method: .post, role: role, body: body, idempotencyKey: nil) { (result: Result<Decision, MarketplaceRemoteFailure>) in
            if case .success(let decision) = result, decision.status != (approve ? "approved" : "rejected") {
                completion(.failure(MarketplaceRemoteFailure(kind: .unknown, statusCode: nil, detail: "扫码授权结果无法确认，请核对电脑状态。")))
                return
            }
            completion(result)
        }
    }
}
