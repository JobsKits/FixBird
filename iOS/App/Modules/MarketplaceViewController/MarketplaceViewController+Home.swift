//
//  MarketplaceViewController+Home.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

extension MarketplaceViewController {
    func renderHome() {
        addSectionTitle(role == .customer ? "预约维修服务".tr : "师傅工作台".tr)
        if role == .customer {
            addInfoCard("平台统一受理报修需求，师傅接单后上门检测并提交报价。".tr)
            addSectionTitle("选择服务".tr)
            let target = keep(MarketplaceUIFactory.stack())
            contentStack.byAddArrangedSubview(target)
            populateCategories(categories, in: target)
            connectionLabel.byText("正在请求服务端；先显示本机样例".tr)
            let context = requestContext
            retainToken(MarketplaceStore.shared.listCategories { [weak self] outcome in
                guard let self, self.requestContext == context else {
                    return
                }
                self.categories = outcome.value
                self.populateCategories(outcome.value, in: target)
                self.connectionLabel.byText(self.connectionText(outcome))
            })
            addInfoCard("下单后可在“订单”里查看进度、确认报价和取消未接单服务。".tr)
        } else {
            addInfoCard("新订单集中进入接单大厅。接单、到场、报价、维修、完工按状态依次操作。".tr)
            addInfoCard("最多显示最近200条订单；历史翻页尚未开放，可重新加载最新订单。".tr)
            addSectionTitle("接单大厅".tr)
            let pending = keep(MarketplaceUIFactory.stack())
            contentStack.byAddArrangedSubview(pending)
            addSectionTitle("我的维修中订单".tr)
            let active = keep(MarketplaceUIFactory.stack())
            contentStack.byAddArrangedSubview(active)
            let preview = MarketplaceStore.shared.previewOrders(for: role)
            populateWorkerOrders(preview.value, pending: pending, active: active)
            connectionLabel.byText(connectionText(preview))
            let context = requestContext
            retainToken(MarketplaceStore.shared.listOrders(for: context.role) { [weak self] outcome in
                guard let self, self.requestContext == context else {
                    return
                }
                self.populateWorkerOrders(outcome.value, pending: pending, active: active)
                self.connectionLabel.byText(self.connectionText(outcome))
                self.appendDemoResult()
            })
        }
    }

    private func populateCategories(_ values: [String], in target: UIStackView) {
        target.byRemoveAllArrangedSubviews()
        guard values.isEmpty == false else {
            addEmptyStateButton("暂无可用服务分类，点此重新加载。".tr, to: target)
            return
        }
        values.forEach { category in
            let button = keep(MarketplaceUIFactory.button(category.tr + "　›") { [weak self] in
                self?.presentOrderForm(category: category)
            })
            target.byAddArrangedSubview(button)
        }
    }

    private func populateWorkerOrders(_ orders: [RepairOrder], pending: UIStackView, active: UIStackView) {
        populateOrders(orders.filter { $0.status == .pendingWorker }, in: pending, emptySubtitle: "目前没有待接订单。".tr)
        populateOrders(orders.filter { $0.workerId == role.actorID && $0.status != .completed && $0.status != .cancelled }, in: active, emptySubtitle: "接单后，工单会显示在这里。".tr)
    }
}
