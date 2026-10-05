//
//  JobsSplashLocalization.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

import Foundation

enum JobsSplashLocalization {
    static func skipTitle(language: JobsSplashLanguage, remainingSeconds: Int?) -> String {
        let bundle = localizedBundle(language: language)
        let skip = bundle.localizedString(
            forKey: "jobs_splash_skip",
            value: "Skip",
            table: nil
        )
        guard let remainingSeconds else { return skip }
        let format = bundle.localizedString(
            forKey: "jobs_splash_countdown_format",
            value: "%@ %d",
            table: nil
        )
        return String(format: format, locale: bundle.preferredLocalizations.first.map(Locale.init(identifier:)), skip, remainingSeconds)
    }

    static func remoteVideoWiFiDownloadNotice(language: JobsSplashLanguage) -> String {
        localizedBundle(language: language).localizedString(
            forKey: "jobs_splash_remote_video_wifi_notice",
            value: "Video downloads on Wi-Fi only",
            table: nil
        )
    }

    private static func localizedBundle(language: JobsSplashLanguage) -> Bundle {
        let resourceBundle = jobsResourceBundle()
        let languageCode: String
        switch language {
        /// 处理 .system 分支
        case .system:
            languageCode = Locale.preferredLanguages.first ?? "en"
        /// 处理 .code 分支
        case let .code(code):
            languageCode = code
        }
        for candidate in languageCandidates(languageCode) {
            if let path = resourceBundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        };return resourceBundle
    }

    private static func jobsResourceBundle() -> Bundle {
        let sourceBundle = Bundle(for: JobsSplashBundleToken.self)
        guard let url = sourceBundle.url(forResource: "JobsSwiftSplashResources", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            return sourceBundle
        };return bundle
    }

    private static func languageCandidates(_ rawCode: String) -> [String] {
        let code = rawCode.replacingOccurrences(of: "_", with: "-")
        let lowercasedCode = code.lowercased()
        if lowercasedCode.hasPrefix("zh-hant") || lowercasedCode.hasPrefix("zh-tw") || lowercasedCode.hasPrefix("zh-hk") {
            return ["zh-Hant", "zh-Hans", "en"]
        }
        if lowercasedCode.hasPrefix("zh") {
            return ["zh-Hans", "zh-Hant", "en"]
        }
        let language = code.split(separator: "-").first.map(String.init) ?? "en"
        return [code, language, "en"]
    }
}

private final class JobsSplashBundleToken: NSObject {}
