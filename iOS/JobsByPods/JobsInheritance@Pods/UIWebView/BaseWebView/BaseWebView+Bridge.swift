//
//  BaseWebView+Bridge.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit
import JobsSwiftBaseDefines

// ===== ScriptMessageHandler（iOS < 14）=====
extension BaseWebView: WKScriptMessageHandler {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        let channel = message.jobsChannel
        handleScriptMessage(channel: channel, body: message.body, reply: { _, _ in })
    }
}
// ===== WithReply（iOS 14+）=====
@available(iOS 14.0, *)
extension BaseWebView: WKScriptMessageHandlerWithReply {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage,
                                      replyHandler: @escaping (Any?, String?) -> Void) {
        let channel = message.jobsChannel
        handleScriptMessage(channel: channel, body: message.body, reply: replyHandler)
    }
}
// ===== 统一消息处理 =====
public extension BaseWebView {
    @MainActor
    func handleScriptMessage(channel: String,
                             body: Any,
                             reply: @escaping (Any?, String?) -> Void) {
        // 1) 先拦截 H5 的 iOSBridge（{action,message?,callback?}）
        if channel == mobileBridgeName {
            handleIOSBridgeMessage(body)
            return
        }
        // 2) 前端 console 透传
        if channel == consoleName {
            if let dict = body as? [String: Any],
               let level = dict["level"] as? String,
               let args = dict["args"] {
                print("[JS:\(level)] \(args)")
            };return
        }
        // 3) 原有的 bridge
        guard channel == bridgeName else { return }
        let dictBody: [String: Any]
        if let d = body as? [String: Any] {
            dictBody = d
        } else if let s = body as? String,
                  let data = s.data(using: .utf8),
                  let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            dictBody = d
        } else {
            print("Invalid bridge message:", body)
            return
        }
        let api = dictBody["name"] as? String ?? ""
        let payload = dictBody["payload"]
        let reqId = dictBody["id"] as? Int
        guard let handler = handlers[api] else {
            if #available(iOS 14.0, *), reqId == nil {
                reply(["error": "unhandled:\(api)"], nil)
            } else if let reqId {
                jsReturn(id: reqId, value: ["error": "unhandled:\(api)"])
            };return
        }
        handler(payload) { [weak self] value in
            guard let self else { return }
            if #available(iOS 14.0, *), reqId == nil {
                reply(value, nil)
            } else if let reqId {
                self.jsReturn(id: reqId, value: value)
            }
        }
    }

    @MainActor
    func jsReturn(id: Int, value: Any?) {
        let js = "window.__nativeReturn && window.__nativeReturn(\(id), \(Self.toJSONLiteral(value)));"
        webView.jobsEval(js)
    }
}

// MARK: - iOSBridge（MobileBridge）
extension BaseWebView {
    @MainActor
    func handleIOSBridgeMessage(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }
        let action = (dict["action"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let callback = (dict["callback"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else { return }
        // 1) 查找注册的处理器
        if let handler = mobileActionHandlers[action] {
            handler(dict) { [weak self] value in
                guard let self, !callback.isEmpty else { return }
                let js = """
                try { (window[\(Self.quote(callback))] || function(){})(\(Self.toJSONLiteral(value)));
                } catch(e) { console && console.error(e); }
                """
                self.webView.jobsEval(js)
            };return
        }
        // 2) 没有注册时：默认 getToken（可选）
        if action == "getToken", let f = mobileConfig.tokenProvider {
            if #available(iOS 13.0, *) {
                onMainAsync { [weak self] in
                    guard let self else { return }
                    let token = await f() ?? ""
                    guard !callback.isEmpty else { return }
                    let js = "(window[\(Self.quote(callback))]||function(){})('\\(token)')"
                    self.webView.jobsEval(js)
                }
            } else {
                guard !callback.isEmpty else { return }
                let js = "(window[\(Self.quote(callback))]||function(){})('')"
                self.webView.jobsEval(js)
            };return
        }
        mobileConfig.onUnknownAction?(action, dict)
    }
}
