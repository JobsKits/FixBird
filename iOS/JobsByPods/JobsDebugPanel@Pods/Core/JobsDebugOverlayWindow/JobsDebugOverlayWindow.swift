//
//  JobsDebugOverlayWindow.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit

final class JobsDebugOverlayWindow: UIWindow {
    weak var hostWindow: UIWindow?

    static func make(scene: UIWindowScene, host: UIWindow) -> JobsDebugOverlayWindow {
        let window = JobsDebugOverlayWindow(windowScene: scene)
        return window.byHostWindow(host)
    }

    static func make(host: UIWindow) -> JobsDebugOverlayWindow {
        return JobsDebugOverlayWindow(frame: host.bounds).byHostWindow(host)
    }

    @discardableResult
    func byHostWindow(_ host: UIWindow) -> Self {
        hostWindow = host
        return self
    }

    override var canBecomeKey: Bool {
        return false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let controller = rootViewController as? JobsDebugButtonVC,
              controller.containsButton(point, from: self) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
#endif
