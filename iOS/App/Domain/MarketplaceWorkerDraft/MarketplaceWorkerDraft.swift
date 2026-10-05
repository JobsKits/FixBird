//
//  MarketplaceWorkerDraft.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation

struct MarketplaceWorkerDraft {
    var displayName = ""
    var contactPhone = ""
    var serviceAreas: [String] = []
    var skills: [String] = []
    var bio = ""
    var assetIds: [String] = []
    var expectedRevision = 0

    init(application: MarketplaceWorkerApplication? = nil) {
        if let application {
            displayName = application.displayName
            contactPhone = application.contactPhone
            serviceAreas = application.serviceAreas
            skills = application.skills
            bio = application.bio
            assetIds = application.assetIds
            expectedRevision = application.revision
        }
    }

    var validationMessage: String? {
        guard (1...120).contains(displayName.unicodeScalars.count), (1...40).contains(contactPhone.unicodeScalars.count), bio.unicodeScalars.count <= 2000 else {
            return "姓名限120字，联系方式限40字，简介限2000字。"
        }
        for values in [serviceAreas, skills] {
            guard (1...20).contains(values.count), Set(values).count == values.count,
                  values.allSatisfy({ (1...120).contains($0.unicodeScalars.count) }) else {
                return "服务区域和技能各填1至20项，每项限120字且不能重复。"
            }
        }
        guard (1...6).contains(assetIds.count), Set(assetIds).count == assetIds.count else {
            return "请先上传1至6张资质图片。"
        }
        return nil
    }

    static func items(from text: String) -> [String] {
        return text.replacingOccurrences(of: "，", with: ",").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
    }
}
