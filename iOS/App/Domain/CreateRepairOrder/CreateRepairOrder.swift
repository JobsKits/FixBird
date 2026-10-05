//
//  CreateRepairOrder.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct CreateRepairOrder: Encodable, Equatable {
    var category: String
    var equipment: String
    var issue: String
    var address: String
    var scheduledAt: String

    var validationMessageKey: String? {
        guard equipment.isEmpty == false, issue.isEmpty == false, address.isEmpty == false else {
            return "设备、故障描述和上门地址必填。"
        }
        /// 与 Go 的 rune 数量一致，避免组合字符绕过服务端长度限制。
        guard equipment.unicodeScalars.count <= 160, issue.unicodeScalars.count <= 4000, address.unicodeScalars.count <= 500 else {
            return "设备最多160字，故障最多4000字，地址最多500字。"
        }
        guard scheduledAt.isEmpty == false else {
            return nil
        }
        guard hasValidAppointment else {
            return "期望时间请留空或填写带时区的日期，例如2026-10-05T14:00:00+08:00。"
        }
        return nil
    }

    private var hasValidAppointment: Bool {
        let pattern = #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})$"#
        guard scheduledAt.range(of: pattern, options: .regularExpression) != nil else {
            return false
        }
        let date = scheduledAt.prefix(10).split(separator: "-").compactMap { Int($0) }
        let time = scheduledAt.dropFirst(11).prefix(8).split(separator: ":").compactMap { Int($0) }
        guard date.count == 3, time.count == 3,
              (1...12).contains(date[1]), date[2] >= 1,
              time[0] < 24, time[1] < 60, time[2] < 60 else {
            return false
        }
        /// Foundation 的 ISO 日期解析会将 2 月 30 日和 25 点顺延，需显式校验。
        let leapYear = date[0] % 4 == 0 && (date[0] % 100 != 0 || date[0] % 400 == 0)
        let daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard date[2] <= daysInMonth[date[1] - 1] else {
            return false
        }
        if scheduledAt.hasSuffix("Z") {
            return true
        }
        let zone = scheduledAt.suffix(5).split(separator: ":").compactMap { Int($0) }
        return zone.count == 2 && zone[0] < 24 && zone[1] < 60
    }
}
