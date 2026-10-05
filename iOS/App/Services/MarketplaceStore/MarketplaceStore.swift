//
//  MarketplaceStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceStore {
    static let shared = MarketplaceStore()

    private let client: MarketplaceAPIClient
    private let cache: MarketplaceOrderCache

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared, defaults: MarketplaceCacheStorage = UserDefaults.standard) {
        self.client = client
        cache = MarketplaceOrderCache(defaults: defaults)
    }

    func previewOrders(for role: MarketplaceRole) -> MarketplaceOutcome<[RepairOrder]> {
        let scope = scope(for: role)
        if let snapshot = cache.snapshot(for: scope) {
            return MarketplaceOutcome(value: snapshot, source: .snapshot)
        }
        return MarketplaceOutcome(value: cache.demoOrders(for: scope), source: .demo)
    }

    @discardableResult
    func listOrders(for role: MarketplaceRole, completion: @escaping (MarketplaceOutcome<[RepairOrder]>) -> Void) -> JobsRequestToken? {
        let scope = scope(for: role)
        return client.send(path: "/api/v1/orders?limit=200", method: .get, role: role, body: nil, idempotencyKey: nil) { [weak self] (result: Result<[RepairOrder], MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 完整替换当前身份快照，不将远端记录写进演示仓储。
            case .success(let orders):
                self.cache.replaceSnapshot(orders, for: scope)
                completion(MarketplaceOutcome(value: orders, source: .server))
            /// 无论失败原因，都保留可操作的独立本地演示。
            case .failure(let failure):
                completion(MarketplaceOutcome(value: self.cache.demoOrders(for: scope), source: .demo, failure: failure))
            }
        }
    }

    @discardableResult
    func listCategories(completion: @escaping (MarketplaceOutcome<[String]>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/categories", method: .get, role: .customer, body: nil, idempotencyKey: nil) { (result: Result<[String], MarketplaceRemoteFailure>) in
            switch result {
            /// 成功使用真实分类，空列表同样有明确含义。
            case .success(let categories):
                completion(MarketplaceOutcome(value: categories, source: .server))
            /// 请求失败继续显示本地服务分类。
            case .failure(let failure):
                completion(MarketplaceOutcome(value: RepairCategory.all, source: .demo, failure: failure))
            }
        }
    }

    func createOrder(_ input: CreateRepairOrder, idempotencyKey: String, completion: @escaping (MarketplaceOutcome<RepairOrder?>) -> Void) {
        let scope = scope(for: .customer)
        let body: [String: JobsValue] = [
            "category": JobsValue(input.category),
            "equipment": JobsValue(input.equipment),
            "issue": JobsValue(input.issue),
            "address": JobsValue(input.address),
            "scheduledAt": JobsValue(input.scheduledAt)
        ]
        client.send(path: "/api/v1/orders", method: .post, role: .customer, body: body, idempotencyKey: idempotencyKey) { [weak self] (result: Result<RepairOrder, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 真实订单只进入当前身份快照。
            case .success(let order):
                self.cache.upsertSnapshot(order, for: scope)
                completion(MarketplaceOutcome(value: order, source: .server))
            /// 相同表单重试复用键和演示订单，不制造多个本地副本。
            case .failure(let failure):
                let existing = self.cache.demoOrders(for: scope).first { $0.id == "demo-create-" + idempotencyKey }
                let order = existing ?? self.makeLocalOrder(input, idempotencyKey: idempotencyKey)
                self.cache.saveDemo(order, in: scope)
                completion(MarketplaceOutcome(value: order, source: .demo, failure: failure))
            }
        }
    }

    func transition(order: RepairOrder, action: String, role: MarketplaceRole, quoteCents: Int64 = 0, completion: @escaping (MarketplaceOutcome<RepairOrder?>) -> Void) {
        let scope = scope(for: role)
        let body: [String: JobsValue]? = action == "quote" ? ["quoteCents": JobsValue(quoteCents)] : nil
        client.send(path: "/api/v1/orders/\(order.id)/\(action)", method: .post, role: role, body: body, idempotencyKey: nil) { [weak self] (result: Result<RepairOrder, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 服务端确认后更新快照，随后 GET 仍是权威来源。
            case .success(let updated):
                self.cache.upsertSnapshot(updated, for: scope)
                completion(MarketplaceOutcome(value: updated, source: .server))
            /// 演示使用独立 ID 和最新演示状态，绝不污染或重放真实订单。
            case .failure(let failure):
                let demo = self.cache.demoCopy(of: order, in: scope)
                let updated = self.applyLocal(action, to: demo, role: role, quoteCents: quoteCents)
                if let updated {
                    self.cache.saveDemo(updated, in: scope)
                }
                completion(MarketplaceOutcome(value: updated, source: .demo, failure: failure))
            }
        }
    }

    private func scope(for role: MarketplaceRole) -> MarketplaceOrderCache.Scope {
        return MarketplaceOrderCache.Scope(environment: MarketplaceEnvironment.current.rawValue, baseURL: MarketplaceEnvironment.baseURLString, role: role, actorID: role.actorID)
    }

    private func makeLocalOrder(_ input: CreateRepairOrder, idempotencyKey: String) -> RepairOrder {
        let now = Date().ISO8601Format()
        return RepairOrder(id: "demo-create-" + idempotencyKey, customerId: MarketplaceRole.customer.actorID, workerId: "", category: input.category, equipment: input.equipment, issue: input.issue, address: input.address, scheduledAt: input.scheduledAt, status: .pendingWorker, paymentStatus: "not_started", quotedAmountCents: 0, platformFeeCents: 0, workerShareCents: 0, createdAt: now, updatedAt: now)
    }

    private func applyLocal(_ action: String, to order: RepairOrder, role: MarketplaceRole, quoteCents: Int64) -> RepairOrder? {
        var updated = order
        switch action {
        /// 师傅接受待接工单。
        case "accept" where role == .worker && order.status == .pendingWorker:
            updated.workerId = role.actorID
            updated.status = .accepted
        /// 本人到场登记。
        case "arrive" where role == .worker && order.workerId == role.actorID && order.status == .accepted:
            updated.status = .arrived
        /// 与服务端一致的整数分范围。
        case "quote" where role == .worker && order.workerId == role.actorID && order.status == .arrived && (1...MarketplaceMoney.maximumQuoteCents).contains(quoteCents):
            updated.quotedAmountCents = quoteCents
            updated.status = .quotePending
        /// 用户确认报价后开始服务。
        case "confirm-quote" where role == .customer && order.customerId == role.actorID && order.status == .quotePending:
            updated.status = .inService
        /// 师傅完工后等待收款。
        case "complete" where role == .worker && order.workerId == role.actorID && order.status == .inService:
            updated.status = .awaitingPayment
        /// 未接单时允许用户取消。
        case "cancel" where role == .customer && order.customerId == role.actorID && order.status == .pendingWorker:
            updated.status = .cancelled
        /// 非法迁移不制造成功结果。
        default:
            return nil
        }
        updated.updatedAt = Date().ISO8601Format()
        return updated
    }
}
