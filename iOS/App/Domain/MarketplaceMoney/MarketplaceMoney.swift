//
//  MarketplaceMoney.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

enum MarketplaceMoney {
    static let maximumQuoteCents: Int64 = 100_000_000

    /// 台账累计金额也按整数分显示，包含 Int64.min 时不做取反溢出。
    static func amountText(cents: Int64) -> String {
        let magnitude = cents.magnitude
        let fraction = magnitude % 100
        return (cents < 0 ? "-" : "") + "¥" + String(magnitude / 100) + "." + (fraction < 10 ? "0" : "") + String(fraction)
    }

    /// 金额先按十进制校验精度和业务范围，再转为整数分，避免 Double 越界或舍入。
    static func quoteCents(from input: String) -> Int64? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard text.range(of: #"^(?:[0-9]+(?:\.[0-9]{1,2})?|\.[0-9]{1,2})$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              amount > 0,
              amount <= Decimal(maximumQuoteCents) / 100,
              let cents = Int64((amount * 100).description),
              (1...maximumQuoteCents).contains(cents) else {
            return nil
        }
        return cents
    }
}
