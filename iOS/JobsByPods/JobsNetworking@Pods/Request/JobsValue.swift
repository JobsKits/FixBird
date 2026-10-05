//
//  JobsValue.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsValue: Sendable {
    public let raw: Any?

    public init(_ raw: Any?) {
        self.raw = raw
    }
}

@available(*, deprecated, renamed: "JobsValue")
public typealias AnySendable = JobsValue

public extension Dictionary where Key == String, Value == JobsValue {
    func normalizedJSONObject() -> [String: Any] {
        reduce(into: [String: Any]()) { partialResult, item in
            partialResult[item.key] = JobsValueNormalizer.normalize(item.value.raw)
        }
    }
}

enum JobsValueNormalizer {
    static func normalize(_ value: Any?) -> Any {
        guard let value else { return NSNull() }
        switch value {
        /// 处理 JobsValue 类型分支
        case let value as JobsValue:
            return normalize(value.raw)
        /// 处理 [String: JobsValue] 类型分支
        case let value as [String: JobsValue]:
            return value.normalizedJSONObject()
        /// 处理 [String: Any] 类型分支
        case let value as [String: Any]:
            return value.mapValues(normalize)
        /// 处理 [JobsValue] 类型分支
        case let value as [JobsValue]:
            return value.map { normalize($0.raw) }
        /// 处理 [Any] 类型分支
        case let value as [Any]:
            return value.map(normalize)
        /// 处理 URL 类型分支
        case let value as URL:
            return value.absoluteString
        /// 处理 Date 类型分支
        case let value as Date:
            return ISO8601DateFormatter().string(from: value)
        /// 处理 Data 类型分支
        case let value as Data:
            return value.base64EncodedString()
        /// 未匹配已知分支时执行兜底处理
        default:
            return value
        }
    }
}
