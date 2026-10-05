//
//  MarketplaceAccountStore.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import JobsNetworking

final class MarketplaceAccountStore {
    static let shared = MarketplaceAccountStore()
    private let client: MarketplaceAPIClient
    private let sessions: MarketplaceSessionCenter

    init(client: MarketplaceAPIClient = MarketplaceAPI.shared, sessions: MarketplaceSessionCenter = .shared) {
        self.client = client
        self.sessions = sessions
    }

    func authenticate(_ input: MarketplaceAuthInput, registering: Bool, completion: @escaping (Result<MarketplaceUser, MarketplaceRemoteFailure>) -> Void) {
        var body = ["username": JobsValue(input.username), "password": JobsValue(input.password)]
        body["device"] = JobsValue(["kind": "mobile", "label": "iOS App", "platform": "iOS"])
        if registering {
            body["displayName"] = JobsValue(input.displayName)
            body["role"] = JobsValue(input.role.rawValue)
        }
        let path = registering ? "/api/v1/auth/register" : "/api/v1/auth/login"
        client.send(path: path, method: .post, role: input.role, body: body, idempotencyKey: nil) { [weak self] (result: Result<MarketplaceSession, MarketplaceRemoteFailure>) in
            guard let self else {
                return
            }
            switch result {
            /// 只有真实成功且已安全保存的会话才称为登录成功。
            case .success(let session):
                guard session.isUsable, session.user.marketplaceRole == input.role else {
                    completion(.failure(MarketplaceRemoteFailure(kind: .rejected, statusCode: nil, detail: "账号身份与当前选择不一致，请选择对应身份后登录；后台账号请使用 Web。")))
                    return
                }
                guard self.sessions.save(session, notice: registering ? "账号已创建并登录。" : "登录成功。") else {
                    completion(.failure(MarketplaceRemoteFailure(kind: .unavailable, statusCode: nil, detail: "安全保存登录状态失败，请重试。")))
                    return
                }
                completion(.success(session.user))
            /// 登录失败不能偷偷生成已登录账号。
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }

    @discardableResult
    func refreshUser(completion: @escaping (Result<MarketplaceUser, MarketplaceRemoteFailure>) -> Void) -> JobsRequestToken? {
        return client.send(path: "/api/v1/auth/me", method: .get, role: sessions.currentRole ?? .customer, body: nil, idempotencyKey: nil, completion: completion)
    }

    func changePassword(currentPassword: String, password: String, completion: @escaping (Result<EmptyResponse, MarketplaceRemoteFailure>) -> Void) {
        let token = sessions.current?.token
        client.send(path: "/api/v1/auth/password", method: .post, role: sessions.currentRole ?? .customer,
                    body: ["currentPassword": JobsValue(currentPassword), "password": JobsValue(password)], idempotencyKey: nil) { [weak self] (result: Result<EmptyResponse, MarketplaceRemoteFailure>) in
            if case .success = result, let self, self.sessions.current?.token == token {
                self.sessions.clear(notice: "密码已修改，请重新登录。")
            }
            completion(result)
        }
    }

    func logout() {
        let scope = sessions.scope
        let token = sessions.current?.token
        var completed = false
        client.send(path: "/api/v1/auth/logout", method: .post, role: sessions.currentRole ?? .customer, body: nil, idempotencyKey: nil) { [weak self] (result: Result<EmptyResponse, MarketplaceRemoteFailure>) in
            completed = true
            guard let self else {
                return
            }
            /// 迟到的注销响应不能清掉同环境内刚登录的新会话。
            if self.sessions.scope == scope, let currentToken = self.sessions.current?.token, currentToken != token {
                return
            }
            let notice: String
            switch result {
            /// 服务端明确确认会话撤销。
            case .success:
                notice = "本机已退出，服务端会话已撤销。"
            /// 本地清除不代表服务端撤销成功。
            case .failure:
                notice = "本机已退出；服务端注销未确认。"
            }
            self.sessions.clear(scope: scope, notice: notice)
        }
        if completed == false {
            sessions.clear(scope: scope, notice: "本机已退出；正在请求服务端注销。")
        }
    }
}
