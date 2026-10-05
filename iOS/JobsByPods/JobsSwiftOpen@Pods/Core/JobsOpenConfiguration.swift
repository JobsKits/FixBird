//
//  JobsOpenConfiguration.swift
//  JobsSwiftOpen
//
//  Created by Jobs on 2026年6月24日，星期三.
//

import Foundation

public enum JobsOpenMode {
    case inApp
    case externalBrowser
}

public final class JobsOpenConfiguration {
    public var url: URL
    public var mode: JobsOpenMode
    public var title: String?
    public var animated: Bool
    public var completion: ((Bool) -> Void)?

    public init(
        url: URL = URL(string: "http://www.baidu.com")!,
        mode: JobsOpenMode = .inApp,
        title: String? = nil,
        animated: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.url = url
        self.mode = mode
        self.title = title
        self.animated = animated
        self.completion = completion
    }

    @discardableResult
    public func byURL(_ url: URL) -> Self {
        self.url = url
        return self
    }

    @discardableResult
    public func byMode(_ mode: JobsOpenMode) -> Self {
        self.mode = mode
        return self
    }

    @discardableResult
    public func byTitle(_ title: String?) -> Self {
        self.title = title
        return self
    }

    @discardableResult
    public func byAnimated(_ animated: Bool) -> Self {
        self.animated = animated
        return self
    }

    @discardableResult
    public func byCompletion(_ completion: ((Bool) -> Void)?) -> Self {
        self.completion = completion
        return self
    }
}
