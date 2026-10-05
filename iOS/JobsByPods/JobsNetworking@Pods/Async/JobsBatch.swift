//
//  JobsBatch.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

@available(iOS 13.0, *)
public enum JobsBatch {
    public static func concurrent<Value: Sendable>(
        _ tasks: [() async throws -> Value]
    ) async throws -> [Value] {
        let result = try await JobsWorkflow.concurrent(tasks)
        return result.values
    }

    public static func chain<Value>(
        seed: Value,
        _ steps: [(Value) async throws -> Value]
    ) async throws -> Value {
        try await JobsWorkflow.chain(initial: seed, steps: steps)
    }
}
