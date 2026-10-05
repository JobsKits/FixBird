//
//  MarketplacePrivateAssetClient.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

protocol MarketplacePrivateAssetClient {
    @discardableResult
    func uploadWorkerImage(_ data: Data, completion: @escaping (Result<MarketplaceWorkerAsset, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken?
}
