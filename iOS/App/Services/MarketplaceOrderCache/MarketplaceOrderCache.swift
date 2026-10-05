//
//  MarketplaceOrderCache.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsSwiftBlock

final class MarketplaceOrderCache {
    struct Scope {
        let environment: String
        let baseURL: String
        let role: MarketplaceRole
        let actorID: String

        var suffix: String {
            let parts = [environment, baseURL, role.rawValue, actorID]
            return parts.map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
        }
    }

    private let defaults: MarketplaceCacheStorage

    init(defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.defaults = defaults
    }

    func snapshot(for scope: Scope) -> [RepairOrder]? {
        return read(key: "repair.snapshot.v2." + scope.suffix)
    }

    /// GET 返回的是该身份的权威快照，空数组也必须替换旧数据。
    func replaceSnapshot(_ orders: [RepairOrder], for scope: Scope) {
        write(orders.filter { $0.demoSourceID == nil }, key: "repair.snapshot.v2." + scope.suffix)
    }

    func upsertSnapshot(_ order: RepairOrder, for scope: Scope) {
        var orders = snapshot(for: scope) ?? []
        upsert(order, in: &orders)
        replaceSnapshot(orders, for: scope)
    }

    func demoOrders(for scope: Scope) -> [RepairOrder] {
        if let orders = read(key: "repair.demo.v2." + scope.suffix) {
            return orders
        }
        /// 旧缓存只接管 demo-ID，曾混入其中的真实订单不能进入新演示仓储。
        if scope.actorID == scope.role.demoActorID,
           let legacy = read(key: "repair.demo.orders.\(scope.environment).\(scope.baseURL)") {
            return visible(legacy.filter { $0.id.hasPrefix("demo-") }, for: scope)
        }
        return visible(Self.demoOrders(), for: scope)
    }

    /// 两个演示角色共享同一次演示状态迁移，但每份缓存仍按角色与身份隔离。
    func saveDemo(_ order: RepairOrder, in scope: Scope) {
        let audiences = scope.actorID == scope.role.demoActorID
            ? MarketplaceRole.allCases.map { Scope(environment: scope.environment, baseURL: scope.baseURL, role: $0, actorID: $0.demoActorID) }
            : [scope]
        for audience in audiences {
            var orders = demoOrders(for: audience)
            orders.removeAll { $0.id == order.id }
            if visible([order], for: audience).isEmpty == false {
                orders.insert(order, at: 0)
            }
            write(orders, key: "repair.demo.v2." + audience.suffix)
        }
    }

    func demoCopy(of order: RepairOrder, in scope: Scope) -> RepairOrder {
        if order.id.hasPrefix("demo-") {
            return demoOrders(for: scope).first { $0.id == order.id } ?? order
        }
        if let existing = demoOrders(for: scope).first(where: { $0.demoSourceID == order.id }) {
            return existing
        }
        var copy = order
        copy.id = "demo-copy-" + order.id
        copy.demoSourceID = order.id
        return copy
    }

    private func visible(_ orders: [RepairOrder], for scope: Scope) -> [RepairOrder] {
        switch scope.role {
        /// 用户只看到自己的演示订单。
        case .customer:
            return orders.filter { $0.customerId == scope.actorID }
        /// 师傅看到待接订单和自己的工单。
        case .worker:
            return orders.filter { $0.status == .pendingWorker || $0.workerId == scope.actorID }
        }
    }

    private func upsert(_ order: RepairOrder, in orders: inout [RepairOrder]) {
        orders.removeAll { $0.id == order.id }
        orders.insert(order, at: 0)
    }

    private func read(key: String) -> [RepairOrder]? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder.make { _ in }.decode([RepairOrder].self, from: data)
    }

    private func write(_ orders: [RepairOrder], key: String) {
        let encoder = JSONEncoder.make { _ in }
        guard let data = try? encoder.encode(orders) else {
            return
        }
        defaults.set(data, forKey: key)
    }
    private static func demoOrders() -> [RepairOrder] {
        let now = Date().ISO8601Format()
        return [
            RepairOrder(
                id: "demo-refrigerator-001",
                customerId: MarketplaceRole.customer.actorID,
                workerId: "",
                category: "家电维修",
                equipment: "冰箱 · 海尔",
                issue: "冷藏室不制冷，冷冻室结霜较多",
                address: "上海市浦东新区世纪大道 100 号",
                scheduledAt: "今天 14:00",
                status: .pendingWorker,
                paymentStatus: "not_started",
                quotedAmountCents: 0,
                platformFeeCents: 0,
                workerShareCents: 0,
                createdAt: now,
                updatedAt: now
            ),
            RepairOrder(
                id: "demo-water-heater-002",
                customerId: MarketplaceRole.customer.actorID,
                workerId: MarketplaceRole.worker.actorID,
                category: "家电维修",
                equipment: "热水器 · 美的",
                issue: "热水温度不稳定，需要检查温控器",
                address: "上海市浦东新区张江路 88 号",
                scheduledAt: "今天 16:30",
                status: .accepted,
                paymentStatus: "not_started",
                quotedAmountCents: 0,
                platformFeeCents: 0,
                workerShareCents: 0,
                createdAt: now,
                updatedAt: now
            )
        ]
    }

}
