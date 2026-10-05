//
//  MarketplaceLedgerViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceLedgerViewController: MarketplaceFeatureViewController {
    var ledgerRole: MarketplaceRole = .worker
    override var screenTitle: String {
        return "我的账务与分润"
    }
    override var activeRole: MarketplaceRole {
        return ledgerRole
    }

    override func drawPage() {
        addInfo("账务仅为模拟台账；人工核销也不会发起真实转账，不代表银行余额。".tr)
        addInfo("汇总为本人全部模拟净发生额；流水最多显示最近200条。".tr)
        let summary = keep(MarketplaceUIFactory.stack())
        let journals = keep(MarketplaceUIFactory.stack())
        contentStack.byAddArrangedSubviews([summary, journals])
        populateSummary(MarketplaceLedgerStore.shared.previewSummary(role: ledgerRole), in: summary)
        populateJournals(MarketplaceLedgerStore.shared.previewJournals(role: ledgerRole), in: journals)
        let expected = context
        retain(MarketplaceLedgerStore.shared.summary(role: ledgerRole) { [weak self] outcome in
            guard let self, self.context == expected else {
                return
            }
            self.populateSummary(outcome, in: summary)
        })
        retain(MarketplaceLedgerStore.shared.journals(role: ledgerRole) { [weak self] outcome in
            guard let self, self.context == expected else {
                return
            }
            self.populateJournals(outcome, in: journals)
        })
    }

    private func populateSummary(_ outcome: MarketplaceOutcome<MarketplaceLedgerSummary>, in target: UIStackView) {
        target.byRemoveAllArrangedSubviews()
        addInfo(sourceText(outcome), to: target)
        let value = outcome.value
        addInfo("净收款额：%@".tr(MarketplaceMoney.amountText(cents: value.collectedCents)), to: target)
        addInfo("师傅累计份额：%@".tr(MarketplaceMoney.amountText(cents: value.workerAccruedCents)), to: target)
        addInfo("已人工核销：%@".tr(MarketplaceMoney.amountText(cents: value.payoutCents)), to: target)
        addInfo("待核销份额：%@".tr(MarketplaceMoney.amountText(cents: value.workerPayableCents)), to: target)
        addInfo("模拟流水总数：%d".tr(value.journalCount), to: target)
    }

    private func populateJournals(_ outcome: MarketplaceOutcome<[MarketplaceLedgerJournal]>, in target: UIStackView) {
        target.byRemoveAllArrangedSubviews()
        addInfo(sourceText(outcome), to: target)
        guard outcome.value.isEmpty == false else {
            addEmpty("暂无账务流水".tr, to: target)
            return
        }
        for journal in outcome.value {
            let kind: String
            switch journal.kind {
            /// 演示收款记账。
            case "collection":
                kind = "模拟收款".tr
            /// 人工核销仅记录账务。
            case "manual_payout":
                kind = "人工核销".tr
            /// 内部冲正记录。
            case "reversal":
                kind = "模拟冲正".tr
            /// 新事件类型保留原文。
            default:
                kind = journal.kind
            }
            let status = journal.status == "reversed" ? "已冲正".tr : "已记账（模拟）".tr
            addInfo(kind + " · " + status + "\n" + MarketplaceMoney.amountText(cents: journal.amountCents)
                    + "\n" + "工单：%@".tr(journal.orderId) + "\n" + journal.occurredAt, to: target)
            addInfo("师傅份额：%@；平台份额：%@".tr(MarketplaceMoney.amountText(cents: journal.workerShareCents), MarketplaceMoney.amountText(cents: journal.platformFeeCents)), to: target)
            if journal.reason.isEmpty == false {
                addInfo(journal.reason, to: target)
            }
        }
    }
}
