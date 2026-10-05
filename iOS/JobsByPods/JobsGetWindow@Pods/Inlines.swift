//
//  Inlines.swift
//  JobsGetWindow
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

// MARK: - 获取 MainWindow
@inline(__always)
public func jobsGetMainWindow() -> UIWindow? {
    let mainWindowBefore13 = jobsGetMainWindowBefore13()
    let mainWindowAfter13 = jobsGetMainWindowAfter13()

    let systemVersion = (UIDevice.current.systemVersion as NSString).floatValue
    let resultWindow = systemVersion >= 13.0 ? mainWindowAfter13 : mainWindowBefore13

    if let window = resultWindow {
        return window
    } else if let window = mainWindowBefore13 {
        return window
    } else if let window = mainWindowAfter13 {
        return window
    } else {
        return nil
    }
}

@inline(__always)
public func jobsGetMainWindowBefore13() -> UIWindow? {
    var window: UIWindow?
    // 使用 AppDelegate 的 window 属性
    if let appDelegateWindow = UIApplication.shared.delegate?.window ?? nil {
        window = appDelegateWindow
    }
    // 若仍未获取，尝试使用 keyWindow（仅在 iOS 13 以前）
    if window == nil {
        if #available(iOS 13, *) {
            // iOS 13+ 不再使用 keyWindow
        } else {
            window = UIApplication.shared.perform(#selector(getter: UIApplication.keyWindow))?.takeUnretainedValue() as? UIWindow
        }
    };return window
}

@inline(__always)
public func jobsGetMainWindowAfter13() -> UIWindow? {
    if #available(iOS 13.0, *) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if windowScene.activationState == .foregroundActive {
                for window in windowScene.windows where window.isKeyWindow {
                    return window
                }
                // fallback to first window
                if let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            }
        }
    };return nil
}
