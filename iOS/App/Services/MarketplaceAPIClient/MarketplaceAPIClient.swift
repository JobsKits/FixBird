//
//  MarketplaceAPIClient.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

protocol MarketplaceAPIClient {
    @discardableResult
    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        role: MarketplaceRole,
        body: [String: JobsValue]?,
        idempotencyKey: String?,
        completion: @escaping (Result<Response, MarketplaceRemoteFailure>) -> Void
    ) -> JobsRequestToken?
}
