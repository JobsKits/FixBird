//
//  UIButton+倒计时.swift
//  JobsCountdownButton
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

public typealias JobsCountdownConfigBuilder = (inout JobsCountdownBtnConfig) -> Void
private var jobsCountdownControllerKey: UInt8 = 0
private var JobsCountdownBinderKey: UInt8 = 0

extension UIButton {
    // MARK: - 通过 AssociatedObject 挂到 UIButton 上（一个按钮一个 binder）
    public var jobs_countdownBinder: JobsCountdownBinder {
        if let obj = objc_getAssociatedObject(self, &JobsCountdownBinderKey) as? JobsCountdownBinder {
            return obj
        }
        let obj = JobsCountdownBinder()
        objc_setAssociatedObject(
            self,
            &JobsCountdownBinderKey,
            obj,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return obj
    }
}

extension UIButton {
    public var jobsCountdownController: JobsCountdownBtnCtrl? {
        get {
            objc_getAssociatedObject(self, &jobsCountdownControllerKey) as? JobsCountdownBtnCtrl
        }
        set {
            objc_setAssociatedObject(
                self,
                &jobsCountdownControllerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension UIButton {
    /// 配置倒计时（不会立刻绑定点击行为，也不会自动 start）
    @discardableResult
    public func byCountdown(_ builder: JobsCountdownConfigBuilder) -> Self {
        var cfg = JobsCountdownBtnConfig()
        builder(&cfg)
        // 覆盖旧 controller
        let controller = JobsCountdownBtnCtrl(button: self, config: cfg)
        self.jobsCountdownController = controller
        return self
    }
    /// 把「点击按钮」和「启动倒计时」自动绑定起来
    @discardableResult
    public func byCountdownOnTapAuto() -> Self {
        /// 普通@点按事件触发
        onTap { [weak self] sender in
            guard let self = self,
                  let ctrl = self.jobsCountdownController
            else { return }
            if ctrl.isRunning {
                // 正在跑
                if ctrl.config.clickableWhileRunning {
                    ctrl.config.onTapWhileRunning?(self, ctrl.config)
                } else {
                    // 不可点就直接吞掉点击
                }
            } else {
                ctrl.start() // 未运行 -> 开始
            }
        };return self
    }
    /// 手动停止并复原 UI
    public func jobsStopCountdown() {
        jobsCountdownController?.stop(resetUI: true)
    }
}
// MARK: - Countdown DSL（把 jobsCountdownController 包起来，直接在按钮上调用）
extension UIButton {
    /// 开始倒计时（等价于 jobsCountdownController?.start()）
    @discardableResult
    public func countdownStart() -> Self {
        jobsCountdownController?.start()
        return self
    }
    /// 停止倒计时
    /// - Parameter resetUI: 是否把按钮 UI 恢复到 start() 之前的基础状态
    @discardableResult
    public func countdownStop(resetUI: Bool = true) -> Self {
        jobsCountdownController?.stop(resetUI: resetUI)
        return self
    }
    /// 重新开始（先 stop(resetUI: false)，再 start）
    @discardableResult
    public func countdownRestart() -> Self {
        jobsCountdownController?.stop(resetUI: false)
        jobsCountdownController?.start()
        return self
    }
    /// 当前是否在倒计时中
    public var isCountingDown: Bool {
        jobsCountdownController?.isRunning ?? false
    }
}
