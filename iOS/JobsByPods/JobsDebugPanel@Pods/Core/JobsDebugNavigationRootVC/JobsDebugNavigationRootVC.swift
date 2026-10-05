//
//  JobsDebugNavigationRootVC.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit
import JobsInheritance
import JobsByUIKit
import JobsSwiftBaseDefines

extension UIViewController {
    func jobsDebugFollowTheme() {
        JobsThemeCenter.shared.bind(self, slot: "JobsDebugPanel.appearance") { object, center in
            guard let controller = object as? UIViewController else {
                return
            }
            // 宿主主题可与系统不同；原生附件、弹窗也要使用同一有效外观。
            controller.byOverrideUserInterfaceStyle(center.isDarkMode ? .dark : .light)
        }
    }
}

/// 没有宿主导航栈时承接 push；返回此页即关闭临时导航容器。
final class JobsDebugNavigationRootVC: BaseVC {
    private var didLeaveRootForMenu = false

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsDebugFollowTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didLeaveRootForMenu else {
            return
        }
        navigationController?.byDismiss(animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if navigationController?.topViewController is JobsDebugMenuVC {
            didLeaveRootForMenu = true
        }
    }
}
#endif
