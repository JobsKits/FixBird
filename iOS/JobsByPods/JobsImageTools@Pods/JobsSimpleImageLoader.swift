//
//  JobsSimpleImageLoader.swift
//  JobsImageTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import Foundation
import ImageIO

#if canImport(Kingfisher)
import Kingfisher
#endif
#if canImport(SDWebImage)
import SDWebImage
#endif

public enum JobsImageLoaderPreference {
    case automatic
    case sdwebimage
    case kingfisher
    case urlSession
}

public enum JobsImageSource {
    case remote(URL)
    case local(String)

    public init?(_ string: String?) {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else { return nil }
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) {
            self = .remote(url)
        } else {
            self = .local(raw)
        }
    }
}

public enum JobsImageLoadError: Error {
    case invalidSource
    case localImageMissing(String)
    case badData(URL)
    case failed(URL, Error)
}

public struct JobsImageLoadOptions {
    public var preferredLoader: JobsImageLoaderPreference
    public var targetSize: CGSize?
    public var scale: CGFloat
    public var forceRefresh: Bool

    public init(
        preferredLoader: JobsImageLoaderPreference = .automatic,
        targetSize: CGSize? = nil,
        scale: CGFloat = JobsImageLoader.defaultScale,
        forceRefresh: Bool = false
    ) {
        self.preferredLoader = preferredLoader
        self.targetSize = targetSize
        self.scale = scale
        self.forceRefresh = forceRefresh
    }
}

public struct JobsImageLoadResult {
    public let image: UIImage
    public let url: URL?
    public let loaderKind: JobsImageLoaderKind
    public let isCacheHit: Bool
}

public final class JobsImageLoadToken {
    private let onCancel: () -> Void
    private var isCancelled = false

    public init(_ onCancel: @escaping () -> Void = {}) {
        self.onCancel = onCancel
    }

    public func cancel() {
        guard isCancelled == false else { return }
        isCancelled = true
        onCancel()
    }
}

public final class JobsImageLoader {
    public static let shared = JobsImageLoader()
    public static var defaultScale: CGFloat {
        #if os(iOS) || os(tvOS)
        return UIScreen.main.scale
        #elseif os(OSX)
        return NSScreen.main?.backingScaleFactor ?? 2
        #else
        return 2
        #endif
    }

    private let fallbackCache = NSCache<NSURL, UIImage>()
    private let fallbackSession: URLSession

    public init(session: URLSession = .shared) {
        fallbackSession = session
        fallbackCache.countLimit = 240
        fallbackCache.totalCostLimit = 80 * 1024 * 1024
    }

    public func cachedImage(for url: URL) -> UIImage? {
        #if canImport(SDWebImage)
        let sdKey = SDWebImageManager.shared.cacheKey(for: url) ?? url.absoluteString
        if let image = SDImageCache.shared.imageFromMemoryCache(forKey: sdKey) {
            return image
        }
        #endif
        #if canImport(Kingfisher)
        if let image = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: url.absoluteString) {
            return image
        }
        #endif
        return fallbackCache.object(forKey: url as NSURL)
    }

    @discardableResult
    public func load(
        _ source: JobsImageSource?,
        options: JobsImageLoadOptions = .init(),
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        guard let source else {
            DispatchQueue.main.async { completion(.failure(.invalidSource)) };return JobsImageLoadToken()
        }
        switch source {
        /// 处理 .local 分支
        case .local(let name):
            return loadLocalImage(name, completion: completion)
        /// 处理 .remote 分支
        case .remote(let url):
            return loadRemoteImage(url, options: options, completion: completion)
        }
    }

    public func clearMemoryCache() {
        fallbackCache.removeAllObjects()
        #if canImport(SDWebImage)
        SDImageCache.shared.clearMemory()
        #endif
        #if canImport(Kingfisher)
        KingfisherManager.shared.cache.clearMemoryCache()
        #endif
    }
}

private extension JobsImageLoader {
    func loadLocalImage(
        _ name: String,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        if let image = UIImage(named: name) {
            let result = JobsImageLoadResult(image: image, url: nil, loaderKind: .unknown, isCacheHit: true)
            DispatchQueue.main.async { completion(.success(result)) }
        } else {
            DispatchQueue.main.async { completion(.failure(.localImageMissing(name))) }
        };return JobsImageLoadToken()
    }

    func loadRemoteImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        switch resolvedLoader(for: options.preferredLoader) {
        /// 处理 .sdwebimage 分支
        case .sdwebimage:
            return loadWithSDWebImage(url, options: options, completion: completion)
        /// 处理 .kingfisher 分支
        case .kingfisher:
            return loadWithKingfisher(url, options: options, completion: completion)
        /// 合并处理 .urlSession、.unknown 分支
        case .urlSession, .unknown:
            return loadWithURLSession(url, options: options, completion: completion)
        }
    }

    func resolvedLoader(for preference: JobsImageLoaderPreference) -> JobsImageLoaderKind {
        switch preference {
        /// 处理 .sdwebimage 分支
        case .sdwebimage:
            #if canImport(SDWebImage)
            return .sdwebimage
            #else
            return resolvedLoader(for: .automatic)
            #endif
        /// 处理 .kingfisher 分支
        case .kingfisher:
            #if canImport(Kingfisher)
            return .kingfisher
            #else
            return resolvedLoader(for: .automatic)
            #endif
        /// 处理 .urlSession 分支
        case .urlSession:
            return .urlSession
        /// 处理 .automatic 分支
        case .automatic:
            #if canImport(SDWebImage)
            return .sdwebimage
            #elseif canImport(Kingfisher)
            return .kingfisher
            #else
            return .urlSession
            #endif
        }
    }

    #if canImport(Kingfisher)
    func loadWithKingfisher(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        var kfOptions: KingfisherOptionsInfo = []
        if options.forceRefresh { kfOptions.append(.forceRefresh) }
        if let targetSize = options.targetSize, targetSize.width > 1, targetSize.height > 1 {
            kfOptions.append(.processor(DownsamplingImageProcessor(size: targetSize)))
            kfOptions.append(.scaleFactor(options.scale))
            kfOptions.append(.cacheOriginalImage)
        }
        let task = KingfisherManager.shared.retrieveImage(with: url, options: kfOptions) { result in
            DispatchQueue.main.async {
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    completion(.success(.init(
                        image: value.image,
                        url: url,
                        loaderKind: .kingfisher,
                        isCacheHit: value.cacheType.cached
                    )))
                /// 处理 .failure 分支
                case .failure(let error):
                    completion(.failure(.failed(url, error)))
                }
            }
        };return JobsImageLoadToken { task?.cancel() }
    }
    #else
    func loadWithKingfisher(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        loadWithURLSession(url, options: options, completion: completion)
    }
    #endif

    #if canImport(SDWebImage)
    func loadWithSDWebImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        var sdOptions: SDWebImageOptions = [.retryFailed, .highPriority, .scaleDownLargeImages]
        if options.forceRefresh { sdOptions.insert(.refreshCached) }
        var context: [SDWebImageContextOption: Any] = [:]
        if let targetSize = options.targetSize, targetSize.width > 1, targetSize.height > 1 {
            context[.imageThumbnailPixelSize] = CGSize(width: targetSize.width * options.scale,
                                                       height: targetSize.height * options.scale)
        }
        let operation = SDWebImageManager.shared.loadImage(
            with: url,
            options: sdOptions,
            context: context,
            progress: nil
        ) { image, _, error, cacheType, _, imageURL in
            DispatchQueue.main.async {
                if let image, error == nil {
                    completion(.success(.init(
                        image: image,
                        url: imageURL ?? url,
                        loaderKind: .sdwebimage,
                        isCacheHit: cacheType != .none
                    )))
                } else if let error {
                    completion(.failure(.failed(url, error)))
                } else {
                    completion(.failure(.badData(url)))
                }
            }
        };return JobsImageLoadToken { operation?.cancel() }
    }
    #else
    func loadWithSDWebImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        loadWithURLSession(url, options: options, completion: completion)
    }
    #endif

    func loadWithURLSession(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        if options.forceRefresh == false, let image = fallbackCache.object(forKey: url as NSURL) {
            DispatchQueue.main.async {
                completion(.success(.init(image: image, url: url, loaderKind: .urlSession, isCacheHit: true)))
            };return JobsImageLoadToken()
        }
        let task = fallbackSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(.failed(url, error))) };return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(.badData(url))) };return
            }
            guard let image = self.image(from: data, targetSize: options.targetSize, scale: options.scale) else {
                DispatchQueue.main.async { completion(.failure(.badData(url))) };return
            }
            self.fallbackCache.setObject(image, forKey: url as NSURL, cost: data.count)
            DispatchQueue.main.async {
                completion(.success(.init(image: image, url: url, loaderKind: .urlSession, isCacheHit: false)))
            }
        }
        task.resume()
        return JobsImageLoadToken { task.cancel() }
    }

    func image(from data: Data, targetSize: CGSize?, scale: CGFloat) -> UIImage? {
        guard let targetSize, targetSize.width > 1, targetSize.height > 1 else {
            return UIImage(data: data)
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return UIImage(data: data) }
        let maxPixel = max(targetSize.width, targetSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixel))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return UIImage(data: data)
        };return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
