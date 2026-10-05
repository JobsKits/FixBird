//
//  JobsRequestToken.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public final class JobsRequestToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelHandler: (() -> Void)?
    private(set) public var isCancelled = false

    public init() {}

    public func setCancel(_ block: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        cancelHandler = block
    }

    public func cancel() {
        lock.lock()
        let handler = cancelHandler
        isCancelled = true
        lock.unlock()
        handler?()
    }
}
