//
//  JobsSplashPreferences.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

import Foundation

public enum JobsSplashPreferences {
    private static let enabledKey = "JobsSwiftSplash.isEnabledForNextLaunch"
    private static let contentTypeKey = "com.jobs.splash.contentTypeForNextLaunch"

    public static var isEnabledForNextLaunch: Bool {
        get {
            guard UserDefaults.standard.object(forKey: enabledKey) != nil else { return true };return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    public static var contentTypeForNextLaunch: JobsSplashContentType {
        get {
            JobsSplashContentType(rawValue: UserDefaults.standard.integer(forKey: contentTypeKey)) ?? .localImage
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: contentTypeKey)
        }
    }

    @discardableResult
    public static func toggleForNextLaunch() -> Bool {
        isEnabledForNextLaunch.toggle()
        return isEnabledForNextLaunch
    }
}
