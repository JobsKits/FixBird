//
//  MarketplaceOrderForm.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceOrderForm {
    let category: String
    var onSubmit: ((CreateRepairOrder, String) -> Void)?
    var onInvalid: ((String) -> Void)?
    private var submission = MarketplaceOrderSubmission()
    private(set) var isSubmitting = false
    private lazy var alert = UIAlertController.makeAlert("提交%@需求".tr(category.tr))
        .byAddTextField { field in
            field.byPlaceholder("设备 / 品牌".tr)
        }
        .byAddTextField { field in
            field.byPlaceholder("故障描述".tr)
        }
        .byAddTextField { field in
            field.byPlaceholder("上门地址".tr)
        }
        .byAddTextField { field in
            field.byPlaceholder("期望时间：RFC3339或留空".tr)
        }
        .byAddCancel("取消".tr)
        .byAddOK("提交订单".tr) { [weak self] alert, _ in
            self?.submit(fields: alert.textFields ?? [])
        }

    init(category: String) {
        self.category = category
    }

    func present(from host: UIViewController) {
        guard isSubmitting == false else {
            return
        }
        TRBind.consumeMarkerIfNeeded()
        alert.byPresent(host, animated: true)
    }

    func finish() {
        isSubmitting = false
    }

    private func submit(fields: [UITextField]) {
        guard isSubmitting == false, fields.count == 4 else {
            return
        }
        let values = fields.map { ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        let input = CreateRepairOrder(category: category, equipment: values[0], issue: values[1], address: values[2], scheduledAt: values[3])
        if let validation = input.validationMessageKey {
            onInvalid?(validation)
            return
        }
        let requestKey = submission.key(for: input)
        isSubmitting = true
        onSubmit?(input, requestKey)
    }
}
