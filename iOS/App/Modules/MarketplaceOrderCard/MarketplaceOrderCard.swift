//
//  MarketplaceOrderCard.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class MarketplaceOrderCard: UIView {
    private let order: RepairOrder
    private var actionButtons: [UIButton] = []
    private lazy var headingLabel = MarketplaceUIFactory.label(order.category.tr + " · " + order.equipment, size: 17, weight: .semibold)
    private lazy var statusLabel: UILabel = {
        let quote = order.quotedAmountCents > 0 ? order.quoteText : "待师傅检测后报价".tr
        return MarketplaceUIFactory.label(order.status.displayName.tr + "　" + quote, size: 14, weight: .medium)
            .byTextColor(JobsCor.systemBlue)
    }()
    private lazy var detailLabel = MarketplaceUIFactory.label([order.issue, order.address, order.scheduledAt.isEmpty ? "时间待协商".tr : order.scheduledAt].joined(separator: "\n"), size: 13)
        .byTextColor(JobsCor.secondaryLabel)
    private lazy var stack = MarketplaceUIFactory.stack(spacing: 8, margins: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        .byAddArrangedSubviews([headingLabel, statusLabel, detailLabel])
        .byAddTo(self) { make in
            make.edges.equalToSuperview()
        }

    init(order: RepairOrder) {
        self.order = order
        super.init(frame: .zero)
        byBackgroundColor(JobsCor.secondarySystemGroupedBackground)
            .byCornerRadius(12)
            .byClipsToBounds(true)
        _ = stack
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func setActions(_ buttons: [UIButton]) {
        actionButtons.forEach { button in
            stack.byRemoveArrangedSubview(button)
            button.byRemoveFromSuperview()
        }
        actionButtons = buttons
        stack.byAddArrangedSubviews(buttons)
    }
}
