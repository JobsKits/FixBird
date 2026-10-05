//
//  JobsDebugPanel.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit
import JobsByUIKit
import JobsSwiftBaseDefines

@MainActor
public final class JobsDebugPanel {
    public static let shared = JobsDebugPanel()
    public static let environmentDidChangeNotification = Notification.Name("JobsDebugPanelEnvironmentDidChange")
    public static var buttonImage: UIImage? {
        return JobsDebugPanelResource.buttonImage
    }
    public private(set) var environments: [JobsDebugEnvironment] = []
    public private(set) var actions: [JobsDebugAction] = []
    public private(set) var selectedEnvironment: JobsDebugEnvironment?

    private let selectedURLKey = "JobsDebugPanel.Debug.SelectedEnvironmentURL"
    private var environmentDidChange: ((JobsDebugEnvironment) -> Void)?
    private var overlayWindows: [String: JobsDebugOverlayWindow] = [:]
    private let menuControllers = NSMapTable<UIWindow, JobsDebugMenuVC>(
        keyOptions: .weakMemory,
        valueOptions: .weakMemory
    )
    private var notificationTokens: [NSObjectProtocol] = []
    private var started = false
    private var hiddenForCurrentLaunch = false

    private init() {}

    @discardableResult
    public func byEnvironments(_ environments: [JobsDebugEnvironment]) -> Self {
        self.environments = environments.filter { $0.url != nil }
        let saved = UserDefaults.standard.string(forKey: selectedURLKey)
        selectedEnvironment = self.environments.first { $0.urlString == saved } ?? self.environments.first
        if let environment = selectedEnvironment {
            apply(environment)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedURLKey)
        }
        return self
    }

    @discardableResult
    public func byEnvironmentDidChange(_ action: @escaping (JobsDebugEnvironment) -> Void) -> Self {
        environmentDidChange = action
        if let environment = selectedEnvironment {
            action(environment)
        }
        return self
    }

    @discardableResult
    public func byAddAction(_ action: JobsDebugAction) -> Self {
        actions.append(action)
        return self
    }

    @discardableResult
    public func byStart() -> Self {
        guard !started else {
            return self
        }
        started = true
        let center = NotificationCenter.default
        let activationNames: [Notification.Name] = [
            UIScene.didActivateNotification,
            UIApplication.didBecomeActiveNotification,
            UIWindow.didBecomeKeyNotification
        ]
        for name in activationNames {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshWindows()
            })
        }
        notificationTokens.append(center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] notification in
            guard let scene = notification.object as? UIWindowScene else {
                return
            }
            let identifier = scene.session.persistentIdentifier
            self?.overlayWindows.removeValue(forKey: identifier)?.byHidden(true)
        })
        refreshWindows()
        return self
    }

    @discardableResult
    public func byHideForCurrentLaunch() -> Self {
        hiddenForCurrentLaunch = true
        overlayWindows.values.forEach { $0.byHidden(true) }
        overlayWindows.removeAll()
        return self
    }

    public func open(from source: UIViewController) {
        guard let window = source.view.window else {
            return
        }
        open(from: window)
    }

    func toggle(from hostWindow: UIWindow) {
        if closeIfOpen(from: hostWindow) {
            return
        }
        open(from: hostWindow)
    }

    private func closeIfOpen(from hostWindow: UIWindow) -> Bool {
        guard let menu = menuControllers.object(forKey: hostWindow),
              let navigation = menu.navigationController,
              containsController(navigation, in: hostWindow.rootViewController),
              let menuIndex = navigation.viewControllers.firstIndex(where: { $0 === menu }) else {
            return false
        }
        guard navigation.transitionCoordinator == nil,
              !navigation.isBeingPresented,
              !navigation.isBeingDismissed else {
            return true
        }
        // 自定义工具的模态页面先关闭，再退出本次调试导航。
        if let presented = navigation.presentedViewController {
            guard !presented.isBeingPresented, !presented.isBeingDismissed else {
                return true
            }
            presented.byDismiss(animated: true) { [weak self, weak hostWindow] in
                guard let hostWindow else {
                    return
                }
                _ = self?.closeIfOpen(from: hostWindow)
            }
            return true
        }
        menuControllers.removeObject(forKey: hostWindow)
        if navigation.viewControllers.first is JobsDebugNavigationRootVC {
            navigation.byDismiss(animated: true)
        } else if menuIndex > 0 {
            // 环境页和后续自定义页面一起退回打开面板前的宿主页面。
            navigation.popToViewControllerByAnimated(navigation.viewControllers[menuIndex - 1])
        }
        refreshFloatingButtonAccessibility()
        return true
    }

    func refreshFloatingButtonAccessibility() {
        for overlay in overlayWindows.values {
            guard let host = overlay.hostWindow,
                  let buttonController = overlay.rootViewController as? JobsDebugButtonVC else {
                continue
            }
            let menu = menuControllers.object(forKey: host)
            let navigation = menu?.navigationController
            let isOpen = navigation?.viewControllers.contains(where: { $0 === menu }) == true
                && navigation.map { containsController($0, in: host.rootViewController) } == true
            buttonController.updateAccessibility(isPanelOpen: isOpen)
        }
    }

    private func containsController(_ target: UIViewController, in root: UIViewController?) -> Bool {
        guard let root else {
            return false
        }
        if root === target {
            return true
        }
        // 全屏工具会移除底层导航视图，以控制器归属判断本次会话是否仍有效。
        if containsController(target, in: root.presentedViewController) {
            return true
        }
        return root.children.contains { containsController(target, in: $0) }
    }

    func open(from hostWindow: UIWindow) {
        let active = hostWindow.windowScene?.activationState == .foregroundActive
            || (hostWindow.windowScene == nil && UIApplication.shared.applicationState == .active)
        guard active,
              let source = topController(from: hostWindow.rootViewController),
              !(source is JobsDebugMenuVC),
              !(source is JobsDebugEnvironmentsVC),
              !source.isBeingDismissed,
              !source.isBeingPresented else {
            return
        }
        if let alert = source as? UIAlertController {
            guard alert.presentingViewController != nil else {
                return
            }
            // 工具入口覆盖业务弹窗；直接关闭不执行其业务 action，完成后重新解析宿主导航。
            alert.byDismiss(animated: true) { [weak self, weak hostWindow] in
                guard let hostWindow else {
                    return
                }
                self?.open(from: hostWindow)
            }
            return
        }
        let menu = JobsDebugMenuVC()
        if let navigation = source.navigationController ?? source as? UINavigationController {
            guard navigation.transitionCoordinator == nil else {
                return
            }
            if let existingMenu = navigation.viewControllers.first(where: { $0 is JobsDebugMenuVC }) {
                menuControllers.setObject(existingMenu as? JobsDebugMenuVC, forKey: hostWindow)
                navigation.popToViewControllerByAnimated(existingMenu)
            } else {
                menuControllers.setObject(menu, forKey: hostWindow)
                navigation.pushViewControllerByAnimated(menu)
            }
        } else {
            menuControllers.setObject(menu, forKey: hostWindow)
            let navigation = UINavigationController.jobsMake { navigation in
                navigation
                    .byViewControllers([JobsDebugNavigationRootVC()])
                    .byModalPresentationStyle(.fullScreen)
                navigation.jobsDebugFollowTheme()
            }
            // 等临时容器挂载完成再 push，兼容宿主的安全转场闸门。
            navigation.byPresent(source, animated: true) { [weak navigation] in
                guard let navigation else {
                    return
                }
                let push: () -> Void = { [weak navigation] in
                    guard let navigation, navigation.presentingViewController != nil else {
                        return
                    }
                    navigation.pushViewControllerByAnimated(menu)
                }
                if let coordinator = navigation.transitionCoordinator {
                    let accepted = coordinator.animate(alongsideTransition: nil) { _ in
                        DispatchQueue.main.async(execute: push)
                    }
                    if !accepted {
                        DispatchQueue.main.async(execute: push)
                    }
                } else {
                    DispatchQueue.main.async(execute: push)
                }
            }
        }
        refreshFloatingButtonAccessibility()
    }

    func select(_ environment: JobsDebugEnvironment) {
        guard environments.contains(where: { $0 === environment }), environment.url != nil else {
            return
        }
        selectedEnvironment = environment
        apply(environment)
    }

    private func apply(_ environment: JobsDebugEnvironment) {
        UserDefaults.standard.set(environment.urlString, forKey: selectedURLKey)
        environmentDidChange?(environment)
        NotificationCenter.default.post(name: Self.environmentDidChangeNotification, object: environment)
    }

    private func refreshWindows() {
        guard started, !hiddenForCurrentLaunch else {
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            let identifier = scene.session.persistentIdentifier
            guard scene.activationState == .foregroundActive else {
                overlayWindows[identifier]?.byHidden(true)
                continue
            }
            let candidates = scene.windows.filter {
                !($0 is JobsDebugOverlayWindow) && !$0.isHidden && $0.rootViewController != nil
            }
            guard let host = candidates.first(where: { $0.isKeyWindow })
                    ?? candidates.first(where: { $0.windowLevel == .normal }) else {
                continue
            }
            if let overlay = overlayWindows[identifier] {
                overlay
                    .byHostWindow(host)
                    .byHidden(false)
            } else {
                let overlay = JobsDebugOverlayWindow.make(scene: scene, host: host)
                    .byRootViewController(JobsDebugButtonVC())
                    .byWindowLevel(.alert + 100)
                    .byBackgroundColor(JobsCor.clear)
                    .byHidden(false)
                overlayWindows[identifier] = overlay
            }
        }
        if let host = UIApplication.shared.delegate?.window ?? nil,
           host.windowScene == nil,
           UIApplication.shared.applicationState == .active {
            let identifier = "JobsDebugPanel.LegacyWindow"
            if let overlay = overlayWindows[identifier] {
                overlay
                    .byHostWindow(host)
                    .byHidden(false)
            } else {
                overlayWindows[identifier] = JobsDebugOverlayWindow.make(host: host)
                    .byRootViewController(JobsDebugButtonVC())
                    .byWindowLevel(.alert + 100)
                    .byBackgroundColor(JobsCor.clear)
                    .byHidden(false)
            }
        }
        refreshFloatingButtonAccessibility()
    }

    private func topController(from controller: UIViewController?) -> UIViewController? {
        guard let controller else {
            return nil
        }
        if let presented = controller.presentedViewController {
            return topController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return topController(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topController(from: tab.selectedViewController)
        }
        // 抽屉等自定义容器也要沿屏幕内的子控制器找到实际导航栈。
        for child in controller.children.reversed() {
            guard let view = child.viewIfLoaded,
                  let window = view.window,
                  !view.isHidden,
                  view.alpha > 0,
                  view.convert(view.bounds, to: window).intersects(window.bounds) else {
                continue
            }
            return topController(from: child)
        }
        return controller
    }
}
#endif
