//
//  MarketplaceQRLogin.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceQRLogin: Equatable {
    let challengeID: String
    let approvalCode: String

    init?(uri: String) {
        guard let components = URLComponents(string: uri.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "repairmarketplace", components.host == "login",
              components.path.isEmpty, components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil,
              let items = components.queryItems, items.count == 2,
              items.filter({ $0.name == "challengeId" }).count == 1,
              items.filter({ $0.name == "approvalCode" }).count == 1,
              let id = items.first(where: { $0.name == "challengeId" })?.value,
              let code = items.first(where: { $0.name == "approvalCode" })?.value,
              id.range(of: #"^[A-Za-z0-9_-]{1,128}$"#, options: .regularExpression) != nil,
              code.range(of: #"^[A-Za-z0-9_-]{16,256}$"#, options: .regularExpression) != nil else {
            return nil
        }
        challengeID = id
        approvalCode = code
    }
}
