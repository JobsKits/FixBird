//
//  MarketplaceUIFactory.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines

/// 页面公共样式只消费 Jobs 工厂与 DSL，不在业务页散落原生配置。
enum MarketplaceUIFactory {
    static func label(_ text: String, size: CGFloat = 14, weight: UIFont.Weight = .regular) -> UILabel {
        return UILabel.jobsMake { label in
            label
                .byText(text)
                .byFont(JobsFont.systemFont(ofSize: size, weight: weight))
                .byTextColor(JobsCor.label)
                .byNumberOfLines(0)
        }
    }

    static func button(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> UIButton {
        return UIButton.sys()
            .byConfiguration(
                UIButton.Configuration.filled()
                    .byBaseBackgroundColor(selected ? JobsCor.systemTeal : JobsCor.secondarySystemGroupedBackground)
                    .byBaseForegroundColor(selected ? JobsCor.white : JobsCor.label)
                    .byBackground(
                        UIBackgroundConfiguration.clear()
                            .byBackgroundColor(selected ? JobsCor.systemTeal : JobsCor.secondarySystemGroupedBackground)
                            .byCornerRadius(10)
                    )
                    .byContentInsets(NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            )
            .byTitle(title)
            .byTitleFont(JobsFont.systemFont(ofSize: 15, weight: .medium))
            .byNumberOfLines(0)
            .byLineBreakMode(.byWordWrapping)
            .onTap { _ in
                action()
            }
    }

    static func stack(spacing: CGFloat = 12, margins: UIEdgeInsets = .zero) -> UIStackView {
        return UIStackView.jobsMake { stack in
            stack
                .byAxis(.vertical)
                .bySpacing(spacing)
                .byLayoutMargins(margins, relative: true)
        }
    }

    static func card() -> UIView {
        return UIView.jobsMake { view in
            view
                .byBackgroundColor(JobsCor.secondarySystemGroupedBackground)
                .byCornerRadius(12)
                .byClipsToBounds(true)
        }
    }
}
