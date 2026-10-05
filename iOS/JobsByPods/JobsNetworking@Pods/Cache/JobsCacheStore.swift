//
//  JobsCacheStore.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public protocol JobsCacheStore: Sendable {
    func get(key: JobsCacheKey) -> JobsCachedValue?
    func set(key: JobsCacheKey, value: JobsCachedValue)
    func remove(key: JobsCacheKey)
    func removeAll()
}

public struct JobsCachedValue: Codable, Sendable {
    public let data: Data
    public let expiry: Date
    public let responseHeaders: [String: String]

    public init(data: Data, expiry: Date, responseHeaders: [String: String] = [:]) {
        self.data = data
        self.expiry = expiry
        self.responseHeaders = responseHeaders
    }

    public var isExpired: Bool { Date() >= expiry }
}

public final class JobsMemoryCache: JobsCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: JobsCachedValue] = [:]

    public init() {}

    public func get(key: JobsCacheKey) -> JobsCachedValue? {
        lock.lock(); defer { lock.unlock() }
        guard let value = store[key.raw], !value.isExpired else {
            store[key.raw] = nil
            return nil
        };return value
    }

    public func set(key: JobsCacheKey, value: JobsCachedValue) {
        lock.lock(); defer { lock.unlock() }
        store[key.raw] = value
    }

    public func remove(key: JobsCacheKey) {
        lock.lock(); defer { lock.unlock() }
        store[key.raw] = nil
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        store.removeAll()
    }
}

public final class JobsDiskCache: JobsCacheStore, @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()

    public init(namespace: String = "JobsNetworkingCache") {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        dir = base.appendingPathComponent(namespace, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func get(key: JobsCacheKey) -> JobsCachedValue? {
        lock.lock(); defer { lock.unlock() }
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(JobsCachedValue.self, from: data) else {
            return nil
        }
        if wrapper.isExpired {
            try? FileManager.default.removeItem(at: url)
            return nil
        };return wrapper
    }

    public func set(key: JobsCacheKey, value: JobsCachedValue) {
        lock.lock(); defer { lock.unlock() }
        let url = fileURL(for: key)
        if let encoded = try? JSONEncoder().encode(value) {
            try? encoded.write(to: url, options: .atomic)
        }
    }

    public func remove(key: JobsCacheKey) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func fileURL(for key: JobsCacheKey) -> URL {
        let safe = key.raw.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return dir.appendingPathComponent(safe).appendingPathExtension("cache")
    }
}
