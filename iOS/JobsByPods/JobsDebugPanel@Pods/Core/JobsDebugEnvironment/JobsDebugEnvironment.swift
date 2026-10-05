//
//  JobsDebugEnvironment.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import Foundation

public final class JobsDebugEnvironment {
    public private(set) var identifier = ""
    public private(set) var urlString = ""
    public private(set) var remark = ""

    public var title: String { remark }
    public var baseURL: URL? { url }

    public var url: URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil else {
            return nil
        }
        return url
    }

    public init() {}

    @discardableResult
    public func byIdentifier(_ identifier: String) -> Self {
        self.identifier = identifier
        return self
    }

    @discardableResult
    public func byTitle(_ title: String) -> Self {
        remark = title
        return self
    }

    @discardableResult
    public func byBaseURL(_ url: String) -> Self {
        return byURL(url)
    }

    @discardableResult
    public func byURL(_ url: String) -> Self {
        urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return self
    }

    @discardableResult
    public func byRemark(_ remark: String) -> Self {
        self.remark = remark
        return self
    }
}
#endif
