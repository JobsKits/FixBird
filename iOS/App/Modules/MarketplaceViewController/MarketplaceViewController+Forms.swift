//
//  MarketplaceViewController+Forms.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

extension MarketplaceViewController {
    func presentOrderForm(category: String) {
        let form: MarketplaceOrderForm
        if let pendingOrderForm, pendingOrderForm.category == category {
            form = pendingOrderForm
        } else {
            form = MarketplaceOrderForm(category: category)
        }
        pendingOrderForm = form
        form.onInvalid = { [weak self] messageKey in
            self?.showMessage(messageKey.tr)
        }
        form.onSubmit = { [weak self, weak form] input, key in
            guard let self, let form else {
                return
            }
            let context = self.requestContext
            MarketplaceStore.shared.createOrder(input, idempotencyKey: key) { [weak self, weak form] outcome in
                form?.finish()
                guard let self, self.requestContext == context else {
                    return
                }
                self.lastDemoWrite = outcome.source == .demo ? outcome : nil
                if outcome.isOnline {
                    self.pendingOrderForm = nil
                }
                self.selectedTab = .orders
                self.render()
                self.showMessage(outcome.isOnline ? "订单已提交，等待师傅接单。".tr : self.writeMessage(outcome))
            }
        }
        form.present(from: self)
    }

    func presentQuoteForm(for order: RepairOrder) {
        quoteForm = UIAlertController.makeAlert("提交报价".tr, "请输入金额：0.01 至 1,000,000 元，最多两位小数。".tr)
            .byAddTextField { field in
                field.byKeyboardType(.decimalPad)
                    .byPlaceholder("维修金额（元）".tr)
            }
            .byAddCancel("取消".tr)
            .byAddOK("提交".tr) { [weak self] alert, _ in
                guard let amount = alert.textFields?.first?.text,
                      let cents = MarketplaceMoney.quoteCents(from: amount) else {
                    self?.showMessage("金额必须为 0.01 至 1,000,000 元，且最多两位小数。".tr)
                    return
                }
                self?.performTransition(order, action: "quote", quoteCents: cents)
            }
        TRBind.consumeMarkerIfNeeded()
        quoteForm?.byPresent(self, animated: true)
    }

    func performTransition(_ order: RepairOrder, action: String, quoteCents: Int64) {
        let context = requestContext
        MarketplaceStore.shared.transition(order: order, action: action, role: context.role, quoteCents: quoteCents) { [weak self] outcome in
            guard let self, self.requestContext == context else {
                return
            }
            guard outcome.value != nil else {
                self.showMessage(self.writeMessage(outcome) + "\n" + "当前订单状态不允许此操作。".tr)
                return
            }
            self.lastDemoWrite = outcome.source == .demo ? outcome : nil
            self.render()
            self.showMessage(self.writeMessage(outcome))
        }
    }
}
