//
//  JobsSplashConfiguration.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import AVFoundation
import JobsSwiftOpen

public enum JobsSplashLanguage {
    case system
    case code(String)
}

public enum JobsSplashContentType: Int, CaseIterable {
    case localImage
    case localGIF
    case remoteImage
    case localVideo
    case remoteVideo
}

public enum JobsSplashContent {
    case localImage(name: String, bundle: Bundle = .main)
    case localGIF(name: String, bundle: Bundle = .main)
    case remoteImage(URL)
    case localVideo(name: String, fileExtension: String? = nil, bundle: Bundle = .main)
    case remoteVideo(
        URL,
        fallbackName: String? = nil,
        fallbackFileExtension: String? = nil,
        fallbackBundle: Bundle = .main
    )

    public static func localGIF(fileURL: URL) -> Self {
        .localGIF(name: fileURL.path)
    }
}

public enum JobsSplashAction {
    case open(JobsOpenConfiguration)
    case custom((_ splashVC: JobsSplashVC) -> Void)
    case none
}

public final class JobsSplashConfiguration {
    public var content: JobsSplashContent
    public var countdownSeconds: Int?
    public var language: JobsSplashLanguage
    public var isSkipButtonVisible: Bool
    public var skipButtonFrame: CGRect?
    public var skipButtonInsets: UIEdgeInsets
    public var contentMode: UIView.ContentMode
    public var videoGravity: AVLayerVideoGravity
    public var tapAction: JobsSplashAction
    public var shakeAction: JobsSplashAction
    public var onSkip: ((_ splashVC: JobsSplashVC) -> Void)?

    public init(content: JobsSplashContent) {
        self.content = content
        countdownSeconds = nil
        language = .system
        isSkipButtonVisible = true
        skipButtonFrame = nil
        skipButtonInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        contentMode = .scaleAspectFill
        videoGravity = .resizeAspectFill
        tapAction = .open(JobsOpenConfiguration())
        shakeAction = .open(JobsOpenConfiguration())
        onSkip = nil
    }

    @discardableResult
    public func byCountdownSeconds(_ seconds: Int?) -> Self {
        countdownSeconds = seconds.map { max(0, $0) };return self
    }

    @discardableResult
    public func byLanguage(_ language: JobsSplashLanguage) -> Self {
        self.language = language
        return self
    }

    @discardableResult
    public func bySkipButtonVisible(_ visible: Bool) -> Self {
        isSkipButtonVisible = visible
        return self
    }

    @discardableResult
    public func bySkipButtonFrame(_ frame: CGRect?) -> Self {
        skipButtonFrame = frame
        return self
    }

    @discardableResult
    public func bySkipButtonInsets(_ insets: UIEdgeInsets) -> Self {
        skipButtonInsets = insets
        return self
    }

    @discardableResult
    public func byContentMode(_ contentMode: UIView.ContentMode) -> Self {
        self.contentMode = contentMode
        return self
    }

    @discardableResult
    public func byVideoGravity(_ videoGravity: AVLayerVideoGravity) -> Self {
        self.videoGravity = videoGravity
        return self
    }

    @discardableResult
    public func byTapAction(_ action: JobsSplashAction) -> Self {
        tapAction = action
        return self
    }

    @discardableResult
    public func byShakeAction(_ action: JobsSplashAction) -> Self {
        shakeAction = action
        return self
    }

    @discardableResult
    public func bySkip(_ block: ((_ splashVC: JobsSplashVC) -> Void)?) -> Self {
        onSkip = block
        return self
    }
}
