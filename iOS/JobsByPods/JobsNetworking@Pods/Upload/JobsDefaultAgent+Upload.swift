//
//  JobsDefaultAgent+Upload.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

extension JobsDefaultAgent: JobsUploadCapable {
    @discardableResult
    public func upload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) -> JobsRequestToken {
        let token = JobsRequestToken()
        token.setCancel { [weak self] in
            self?.client.cancel(requestId: request.trace.requestId)
        }
        doUpload(request, as: type, token: token, attempt: 0, completion: completion)
        return token
    }

    private func doUpload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        let url = URL(string: request.path, relativeTo: config.baseURL)?.absoluteURL ?? config.baseURL.appendingPathComponent(request.path)
        var headers = request.headers
        let fakeRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
        headers.merge(headerHook.headers(for: fakeRequest)) { _, new in new }
        headers[config.traceHeaderKeys.requestId] = request.trace.requestId
        headers[config.traceHeaderKeys.traceId] = request.trace.traceId
        headers[config.traceHeaderKeys.spanId] = request.trace.spanId
        var afHeaders: HTTPHeaders = [:]
        headers.forEach { afHeaders.add(name: $0.key, value: $0.value) }
        let parts = request.files.compactMap { spec -> JobsMultipartPart? in
            switch spec {
            /// 处理 .file 分支
            case let .file(fileURL, name, fileName, mimeType):
                guard let data = try? Data(contentsOf: fileURL) else { return nil };return JobsMultipartPart(name: name, fileName: fileName, mimeType: mimeType, data: data)
            /// 处理 .data 分支
            case let .data(data, name, fileName, mimeType):
                return JobsMultipartPart(name: name, fileName: fileName, mimeType: mimeType, data: data)
            }
        }
        client.uploadMultipart(
            url: url,
            method: request.method,
            headers: afHeaders,
            form: request.form,
            parts: parts,
            trace: request.trace,
            timeout: request.timeout
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            /// 处理 .success 分支
            case .success(let (data, response)):
                do {
                    let fakeRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
                    let decoded: T = try self.validateAndDecode(data: data, response: response, request: fakeRequest, as: type)
                    completion(.success(decoded))
                } catch let error as JobsError {
                    self.retryUploadIfNeeded(request, as: type, token: token, attempt: attempt, error: error, completion: completion)
                } catch {
                    self.retryUploadIfNeeded(request, as: type, token: token, attempt: attempt, error: .unknown(underlying: error.localizedDescription), completion: completion)
                }
            /// 处理 .failure 分支
            case .failure(let error):
                self.retryUploadIfNeeded(request, as: type, token: token, attempt: attempt, error: error, completion: completion)
            }
        }
    }

    private func retryUploadIfNeeded<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        error: JobsError,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        let baseRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
        let policy = request.retryPolicy ?? config.defaultRetryPolicy
        let decision = policy.decision(for: .init(request: baseRequest, attempt: attempt, error: error))
        guard decision.shouldRetry else {
            completion(.failure(error))
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + decision.delay) { [weak self] in
            guard let self else { return }
            self.doUpload(request, as: type, token: token, attempt: attempt + 1, completion: completion)
        }
    }
}
