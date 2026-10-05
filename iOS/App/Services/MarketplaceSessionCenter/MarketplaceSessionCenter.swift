//
//  MarketplaceSessionCenter.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsSwiftBlock

final class MarketplaceSessionCenter {
    static let shared = MarketplaceSessionCenter()
    static let didChange = Notification.Name("MarketplaceSessionDidChange")
    private let credentials: MarketplaceCredentialStorage
    private var cachedScope: String?
    private var cachedSession: MarketplaceSession?
    private var demoScope: String?
    private(set) var demoRole: MarketplaceRole?
    private(set) var revision = 0
    private(set) var notice: String?

    init(credentials: MarketplaceCredentialStorage = MarketplaceKeychain()) {
        self.credentials = credentials
    }

    var scope: String {
        return Data((MarketplaceEnvironment.current.rawValue + "\n" + MarketplaceEnvironment.baseURLString).utf8).base64EncodedString()
    }

    var current: MarketplaceSession? {
        if cachedScope != scope {
            cachedScope = scope
            cachedSession = credentials.credential(for: scope).flatMap { data in
                try? JSONDecoder.make { _ in }.decode(MarketplaceSession.self, from: data)
            }
        }
        return cachedSession?.isUsable == true ? cachedSession : nil
    }

    var currentRole: MarketplaceRole? {
        return current?.user.marketplaceRole ?? (demoScope == scope ? demoRole : nil)
    }

    var isLocalDemo: Bool {
        return current == nil && demoScope == scope && demoRole != nil
    }

    func configureIdentityProvider() {
        MarketplaceIdentityContext.actorIDProvider = { [weak self] role in
            guard let session = self?.current, session.user.marketplaceRole == role else {
                return role.demoActorID
            }
            return session.user.id
        }
    }

    func save(_ session: MarketplaceSession, notice: String) -> Bool {
        let encoder = JSONEncoder.make { _ in }
        guard session.isUsable, let data = try? encoder.encode(session),
              credentials.saveCredential(data, for: scope) else {
            return false
        }
        cachedScope = scope
        cachedSession = session
        demoScope = nil
        demoRole = nil
        self.notice = notice
        publishChange()
        return true
    }

    func enterLocalDemo(role: MarketplaceRole) {
        guard current == nil else {
            return
        }
        demoScope = scope
        demoRole = role
        notice = "当前为本地演示账号，登录、审核和账务均未获服务端确认。"
        publishChange()
    }

    func clear(scope targetScope: String? = nil, notice: String) {
        let target = targetScope ?? scope
        credentials.removeCredential(for: target)
        guard target == scope else {
            return
        }
        cachedScope = scope
        cachedSession = nil
        demoScope = nil
        demoRole = nil
        self.notice = notice
        publishChange()
    }

    func invalidate(token: String) {
        guard current?.token == token else {
            return
        }
        clear(notice: "登录状态已失效，请重新登录。")
    }

    private func publishChange() {
        revision += 1
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
