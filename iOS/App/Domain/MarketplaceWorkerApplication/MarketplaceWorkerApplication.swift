//
//  MarketplaceWorkerApplication.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceWorkerApplication: Codable, Equatable {
    var id: String
    var workerId: String
    var displayName: String
    var contactPhone: String
    var serviceAreas: [String]
    var skills: [String]
    var bio: String
    var assetIds: [String]
    var status: String
    var revision: Int
    var reviewNote: String
    var reviewedAt: String?
    var createdAt: String
    var updatedAt: String

    var statusTitle: String {
        switch status {
        /// 资料已提交，等待后台人工处理。
        case "pending":
            return "待人工审核"
        /// 仅服务端审批结果可以进入已通过。
        case "approved":
            return "审核已通过"
        /// 查看原因后修改资料重提。
        case "rejected":
            return "审核未通过"
        /// 未知状态保持可见，不推断通过。
        default:
            return "审核状态待确认"
        }
    }

    static func localDraft(actorID: String) -> Self {
        return Self(id: "demo-application", workerId: actorID, displayName: "", contactPhone: "", serviceAreas: [], skills: [], bio: "", assetIds: [], status: "pending", revision: 0, reviewNote: "", reviewedAt: "", createdAt: "", updatedAt: "")
    }
}
