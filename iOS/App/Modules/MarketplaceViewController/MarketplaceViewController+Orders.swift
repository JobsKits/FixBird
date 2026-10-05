//
//  MarketplaceViewController+Orders.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

extension MarketplaceViewController {
    func renderOrders() {
        addSectionTitle(role == .customer ? "我的维修订单".tr : "我的工单".tr)
        addInfoCard("最多显示最近200条订单；历史翻页尚未开放，可重新加载最新订单。".tr)
        let target = keep(MarketplaceUIFactory.stack())
        contentStack.byAddArrangedSubview(target)
        let preview = MarketplaceStore.shared.previewOrders(for: role)
        populateOrders(preview.value, in: target, emptySubtitle: "暂时没有订单记录，点此重新加载。".tr)
        connectionLabel.byText(connectionText(preview))
        let context = requestContext
        retainToken(MarketplaceStore.shared.listOrders(for: context.role) { [weak self] outcome in
            guard let self, self.requestContext == context else {
                return
            }
            self.populateOrders(outcome.value, in: target, emptySubtitle: "暂时没有订单记录，点此重新加载。".tr)
            self.connectionLabel.byText(self.connectionText(outcome))
            self.appendDemoResult()
        })
    }

    func populateOrders(_ orders: [RepairOrder], in target: UIStackView, emptySubtitle: String) {
        target.byRemoveAllArrangedSubviews()
        guard orders.isEmpty == false else {
            addEmptyStateButton(emptySubtitle, to: target)
            return
        }
        orders.forEach { order in
            appendOrderCard(order, to: target)
        }
    }

    func appendDemoResult() {
        guard let outcome = lastDemoWrite, let order = outcome.value else {
            return
        }
        addSectionTitle("本地演示结果（不会同步）".tr)
        addInfoCard(writeMessage(outcome))
        appendOrderCard(order, to: contentStack)
        if let form = pendingOrderForm {
            addActionCard(title: "重试当前下单表单".tr, detail: "相同内容复用请求编号；请先核实结果未知的订单。".tr) { [weak self, weak form] in
                guard let self, let form else {
                    return
                }
                form.present(from: self)
            }
        }
        addActionCard(title: "关闭演示结果".tr, detail: "本地演示仍保留，恢复服务后展示真实订单。".tr) { [weak self] in
            self?.lastDemoWrite = nil
            self?.render()
        }
    }

    private func appendOrderCard(_ order: RepairOrder, to target: UIStackView) {
        let card = keep(MarketplaceOrderCard(order: order))
        card.setActions(orderActions(order))
        target.byAddArrangedSubview(card)
    }

    private func orderActions(_ order: RepairOrder) -> [UIButton] {
        switch role {
        /// 用户确认报价、取消未接单或查看禁用支付入口。
        case .customer:
            if order.status == .quotePending {
                return [transitionButton("确认报价并开始维修".tr, order: order, action: "confirm-quote")]
            }
            if order.status == .pendingWorker {
                return [transitionButton("取消订单".tr, order: order, action: "cancel")]
            }
            if order.status == .awaitingPayment {
                return [MarketplaceUIFactory.button("付款入口（暂未接入）".tr) {}
                    .byEnabled(false)
                    .byAlpha(0.55)]
            }
        /// 师傅按当前状态操作自己的工单。
        case .worker:
            switch order.status {
            /// 待接大厅允许接单。
            case .pendingWorker:
                return [transitionButton("接单".tr, order: order, action: "accept")]
            /// 本人接单后登记到场。
            case .accepted where order.workerId == role.actorID:
                return [transitionButton("确认已到场".tr, order: order, action: "arrive")]
            /// 本人到场后填写报价。
            case .arrived where order.workerId == role.actorID:
                return [MarketplaceUIFactory.button("提交维修报价".tr, selected: true) { [weak self] in
                    self?.presentQuoteForm(for: order)
                }]
            /// 服务中允许本人登记完工。
            case .inService where order.workerId == role.actorID:
                return [transitionButton("维修完成".tr, order: order, action: "complete")]
            /// 其它状态不提供非法动作。
            default:
                break
            }
        }
        return []
    }

    private func transitionButton(_ title: String, order: RepairOrder, action: String) -> UIButton {
        return MarketplaceUIFactory.button(title, selected: true) { [weak self] in
            self?.performTransition(order, action: action, quoteCents: 0)
        }
    }
}
