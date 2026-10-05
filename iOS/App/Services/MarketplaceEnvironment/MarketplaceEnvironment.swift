//
//  MarketplaceEnvironment.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月4日，星期日.
//

import Foundation

/// 只切换头 URL；业务路径始终由 MarketplaceAPI 拼接。
enum MarketplaceEnvironment: String, CaseIterable {
    case test
    case production

    /// 测试地址：模拟器访问本机；真机访问同一局域网内的 Mac。
    static let simulatorBaseURL = "http://127.0.0.1:8080"
    static let deviceBaseURL = "http://192.168.1.7:8080"
    /// 线上地址尚未配置，保留空值，部署后只修改此处。
    static let productionBaseURL = ""
    static let didChange = Notification.Name("MarketplaceEnvironmentDidChange")
    private static let selectionKey = "repair.api.environment"
    private static let testURLKey = "repair.api.testBaseURL"
    private(set) static var revision = 0

    static var current: Self {
        #if DEBUG
        return Self(rawValue: UserDefaults.standard.string(forKey: selectionKey) ?? "") ?? .test
        #else
        return .production
        #endif
    }

    static var testBaseURL: String {
        #if DEBUG
        if let saved = UserDefaults.standard.string(forKey: testURLKey), normalizedBaseURL(saved) != nil {
            return saved
        }
        #endif
        #if targetEnvironment(simulator)
        return simulatorBaseURL
        #else
        return deviceBaseURL
        #endif
    }

    static var baseURLString: String {
        switch current {
        /// 本机测试服务
        case .test:
            return testBaseURL
        /// 未配置时不发出请求，由仓储继续本地演示
        case .production:
            return productionBaseURL
        }
    }

    var title: String {
        switch self {
        /// 本机 Docker 测试环境
        case .test:
            return "本机测试"
        /// 保留未来线上部署入口
        case .production:
            return "线上环境"
        }
    }

    static func normalizedBaseURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              components.port.map({ (1...65535).contains($0) }) ?? true else {
            return nil
        }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    #if DEBUG
    static func select(_ environment: Self, testURL: String? = nil) {
        if let testURL {
            guard let normalized = normalizedBaseURL(testURL) else {
                return
            }
            UserDefaults.standard.set(normalized, forKey: testURLKey)
        }
        UserDefaults.standard.set(environment.rawValue, forKey: selectionKey)
        revision += 1
        NotificationCenter.default.post(name: didChange, object: nil)
    }
    #endif
}
