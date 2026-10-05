//
//  JobsCacheKey.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsCacheKey: Hashable, Sendable {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    public static func make(
        method: HTTPMethod,
        url: URL,
        query: [String: JobsValue]?,
        body: [String: JobsValue]?,
        version: String,
        userScope: String
    ) -> JobsCacheKey {
        let queryText = canonicalString(query)
        let bodyText = canonicalString(body)
        let raw = "\(method.rawValue)|\(url.absoluteString)|q=\(queryText)|b=\(bodyText)|v=\(version)|u=\(userScope)"
        return .init(raw: raw)
    }

    private static func canonicalString(_ payload: [String: JobsValue]?) -> String {
        guard let payload else { return "" };return payload
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(stringify($0.value.raw))" }
            .joined(separator: "&")
    }

    private static func stringify(_ value: Any?) -> String {
        String(describing: JobsValueNormalizer.normalize(value))
    }
}
