//
//  JobsSplashMediaCache.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

import Foundation

public final class JobsSplashMediaCache {
    public static let shared = JobsSplashMediaCache()

    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let pendingVideoURLsKey = "JobsSwiftSplash.pendingVideoURLs"
    private let stateQueue = DispatchQueue(label: "com.jobs.splash.video-preload")
    private var videoTasks: [URL: URLSessionDownloadTask] = [:]
    private var videoCompletions: [URL: [(URL) -> Void]] = [:]
    private var videoRetryAttempts: [URL: Int] = [:]
    private var scheduledVideoRetries: Set<URL> = []
    private lazy var wiFiVideoSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .background
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        return URLSession(configuration: configuration)
    }()

    private init() {
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directoryURL = cachesURL.appendingPathComponent("JobsSwiftSplash", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let pendingURLs = UserDefaults.standard
            .stringArray(forKey: pendingVideoURLsKey)?
            .compactMap(URL.init(string:)) ?? []
        stateQueue.async { [weak self] in
            guard let self else { return }
            pendingURLs.forEach {
                if self.cachedFileURL(for: $0) != nil {
                    self.removePendingVideoURL($0)
                } else {
                    self.startVideoDownload($0)
                }
            }
        }
    }

    func cachedFileURL(for remoteURL: URL) -> URL? {
        let fileURL = localFileURL(for: remoteURL)
        guard fileManager.fileExists(atPath: fileURL.path),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              (values.fileSize ?? 0) > 0 else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        };return fileURL
    }

    public func resumePendingVideoPreloads() {}

    @discardableResult
    func download(
        _ remoteURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> URLSessionDownloadTask? {
        if let cachedURL = cachedFileURL(for: remoteURL) {
            completion(.success(cachedURL))
            return nil
        }
        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] temporaryURL, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) };return
            }
            guard let temporaryURL else {
                let error = NSError(
                    domain: "JobsSwiftSplash.Download",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Remote media download returned no file."]
                )
                DispatchQueue.main.async { completion(.failure(error)) };return
            }
            let destinationURL = self.localFileURL(for: remoteURL)
            do {
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }
                try self.fileManager.moveItem(at: temporaryURL, to: destinationURL)
                DispatchQueue.main.async { completion(.success(destinationURL)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
        return task
    }

    func preloadVideo(
        _ remoteURL: URL,
        completion: ((URL) -> Void)? = nil
    ) {
        if let cachedURL = cachedFileURL(for: remoteURL) {
            stateQueue.async { [weak self] in
                self?.removePendingVideoURL(remoteURL)
            }
            DispatchQueue.main.async {
                completion?(cachedURL)
            };return
        }
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.addPendingVideoURL(remoteURL)
            if let completion {
                self.videoCompletions[remoteURL, default: []].append(completion)
            }
            guard self.videoTasks[remoteURL] == nil,
                  !self.scheduledVideoRetries.contains(remoteURL) else { return }
            self.startVideoDownload(remoteURL)
        }
    }

    private func startVideoDownload(_ remoteURL: URL) {
        guard videoTasks[remoteURL] == nil else { return }
        let task = wiFiVideoSession.downloadTask(with: remoteURL) { [weak self] temporaryURL, response, error in
            guard let self else { return }
            let result: Result<URL, Error>
            if let error {
                result = .failure(error)
            } else if let response = response as? HTTPURLResponse,
                      !(200...299).contains(response.statusCode) {
                result = .failure(self.downloadError(
                    code: response.statusCode,
                    description: "Remote video returned HTTP \(response.statusCode)."
                ))
            } else if let temporaryURL {
                result = self.persistDownloadedFile(
                    temporaryURL,
                    for: remoteURL
                )
            } else {
                result = .failure(self.downloadError(
                    code: -1,
                    description: "Remote video download returned no file."
                ))
            }
            self.stateQueue.async { [weak self] in
                self?.handleVideoDownloadResult(result, for: remoteURL)
            }
        }
        videoTasks[remoteURL] = task
        task.resume()
    }

    private func persistDownloadedFile(
        _ temporaryURL: URL,
        for remoteURL: URL
    ) -> Result<URL, Error> {
        do {
            let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) > 0 else {
                return .failure(downloadError(
                    code: -2,
                    description: "Remote video download returned an empty file."
                ))
            }
            let destinationURL = localFileURL(for: remoteURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return .success(destinationURL)
        } catch {
            return .failure(error)
        }
    }

    private func handleVideoDownloadResult(
        _ result: Result<URL, Error>,
        for remoteURL: URL
    ) {
        videoTasks[remoteURL] = nil
        switch result {
        /// 缓存成功后清理待办，并通知仍然存活的开屏界面
        case let .success(localURL):
            videoRetryAttempts[remoteURL] = nil
            scheduledVideoRetries.remove(remoteURL)
            removePendingVideoURL(remoteURL)
            let completions = videoCompletions.removeValue(forKey: remoteURL) ?? []
            DispatchQueue.main.async {
                completions.forEach { $0(localURL) }
            }
        /// 下载失败后保留待办，使用退避间隔继续等待 Wi-Fi 重试
        case .failure:
            let attempt = (videoRetryAttempts[remoteURL] ?? 0) + 1
            videoRetryAttempts[remoteURL] = attempt
            scheduledVideoRetries.insert(remoteURL)
            stateQueue.asyncAfter(deadline: .now() + retryDelay(for: attempt)) { [weak self] in
                guard let self else { return }
                self.scheduledVideoRetries.remove(remoteURL)
                guard self.cachedFileURL(for: remoteURL) == nil else {
                    self.handleVideoDownloadResult(
                        .success(self.localFileURL(for: remoteURL)),
                        for: remoteURL
                    )
                    return
                }
                self.startVideoDownload(remoteURL)
            }
        }
    }

    private func retryDelay(for attempt: Int) -> TimeInterval {
        let exponent = min(max(0, attempt - 1), 6)
        return min(300, 5 * TimeInterval(1 << exponent))
    }

    private func addPendingVideoURL(_ remoteURL: URL) {
        var pendingURLs = Set(
            UserDefaults.standard.stringArray(forKey: pendingVideoURLsKey) ?? []
        )
        pendingURLs.insert(remoteURL.absoluteString)
        UserDefaults.standard.set(
            pendingURLs.sorted(),
            forKey: pendingVideoURLsKey
        )
    }

    private func removePendingVideoURL(_ remoteURL: URL) {
        var pendingURLs = Set(
            UserDefaults.standard.stringArray(forKey: pendingVideoURLsKey) ?? []
        )
        pendingURLs.remove(remoteURL.absoluteString)
        UserDefaults.standard.set(
            pendingURLs.sorted(),
            forKey: pendingVideoURLsKey
        )
    }

    private func downloadError(
        code: Int,
        description: String
    ) -> NSError {
        NSError(
            domain: "JobsSwiftSplash.VideoPreload",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    private func localFileURL(for remoteURL: URL) -> URL {
        let fileExtension = remoteURL.pathExtension.isEmpty ? "data" : remoteURL.pathExtension
        return directoryURL
            .appendingPathComponent(stableHash(remoteURL.absoluteString))
            .appendingPathExtension(fileExtension)
    }

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        };return String(hash, radix: 16)
    }
}
