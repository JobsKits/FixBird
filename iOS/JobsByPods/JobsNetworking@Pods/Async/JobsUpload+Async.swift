//
//  JobsUpload+Async.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(_Concurrency)
import Foundation

@available(iOS 13.0, *)
public extension JobsUploadCapable {
    func upload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type
    ) async throws -> T {
        var token: JobsRequestToken?
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                token = upload(request, as: type) { result in
                    switch result {
                    /// 处理 .success 分支
                    case .success(let value):
                        continuation.resume(returning: value)
                    /// 处理 .failure 分支
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    token = nil
                }
            }
        } onCancel: {
            token?.cancel()
            token = nil
        }
    }
}
#endif
