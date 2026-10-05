//
//  MarketplaceAuthInput.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceAuthInput {
    var username: String
    var password: String
    var displayName: String
    var role: MarketplaceRole

    func validationMessage(registering: Bool) -> String? {
        guard username.range(of: #"^[A-Za-z0-9_.-]{3,64}$"#, options: .regularExpression) != nil else {
            return "账号需为3至64位字母、数字、下划线、点或横线。"
        }
        guard password.isEmpty == false else {
            return "请输入密码。"
        }
        if registering {
            guard (12...128).contains(password.unicodeScalars.count), password.utf8.count <= 256 else {
                return "密码需为12至128个字符，且不超过256字节。"
            }
            guard displayName.isEmpty == false, displayName.unicodeScalars.count <= 120 else {
                return "请填写120字以内的姓名或称呼。"
            }
        }
        return nil
    }
}
