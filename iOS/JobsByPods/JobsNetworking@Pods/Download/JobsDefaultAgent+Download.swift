//
//  JobsDefaultAgent+Download.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

extension JobsDefaultAgent: JobsDownloadCapable {
    @discardableResult
    public func download(
        _ request: JobsDownloadRequest,
        completion: @escaping (Result<URL, JobsError>) -> Void
    ) -> JobsRequestToken {
        let token = JobsRequestToken()
        token.setCancel { [weak self] in
            self?.client.cancel(requestId: request.trace.requestId)
        }
        var headers = request.headers
        let asRequest = JobsRequest(path: request.absoluteURL.absoluteString, method: .get, headers: request.headers, timeout: request.timeout, trace: request.trace)
        headers.merge(headerHook.headers(for: asRequest)) { _, new in new }
        headers[config.traceHeaderKeys.requestId] = request.trace.requestId
        headers[config.traceHeaderKeys.traceId] = request.trace.traceId
        headers[config.traceHeaderKeys.spanId] = request.trace.spanId
        var afHeaders: HTTPHeaders = [:]
        headers.forEach { afHeaders.add(name: $0.key, value: $0.value) }
        client.download(
            absoluteURL: request.absoluteURL,
            headers: afHeaders,
            destinationURL: request.destinationURL,
            trace: request.trace,
            timeout: request.timeout
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            /// 处理 .success 分支
            case .success(let (url, response)):
                self.config.logger.log(.info, "Download success", meta: [
                    "requestId": request.trace.requestId,
                    "status": String(response.statusCode),
                    "file": url.lastPathComponent
                ])
                completion(.success(url))
            /// 处理 .failure 分支
            case .failure(let error):
                self.config.logger.log(.error, "Download failed", meta: [
                    "requestId": request.trace.requestId,
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        };return token
    }
}
