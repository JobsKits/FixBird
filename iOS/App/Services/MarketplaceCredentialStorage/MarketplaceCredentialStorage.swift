//
//  MarketplaceCredentialStorage.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

protocol MarketplaceCredentialStorage {
    func credential(for key: String) -> Data?
    func saveCredential(_ data: Data, for key: String) -> Bool
    func removeCredential(for key: String)
}
