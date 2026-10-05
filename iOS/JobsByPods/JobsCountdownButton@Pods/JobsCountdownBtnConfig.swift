//
//  JobsCountdownBtnConfig.swift
//  JobsCountdownButton
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftTimer

// MARK: - 公共配置体
public struct JobsCountdownBtnConfig {
    public enum Mode {
        /// 60 -> 59 -> ... -> 0
        case down(from: Int)
        /// 0 -> 1 -> ... -> to
        case up(to: Int)
    }
    /// 计时模式（默认 60s 倒计时）
    public var mode: Mode = .down(from: 60)
    /// 定时器间隔（秒），默认 1s
    public var interval: TimeInterval = 1.0
    /// 使用哪种 JobsSwiftTimer 内核，默认 GCD
    public var timerKind: JobsTimerKind = .gcd
    /// 容忍误差，直接透传给 JobsSwiftTimerConfig
    public var tolerance: TimeInterval = 0.01
    /// 是否在 `start()` 时先渲染一次初始值（例如：立刻显示 “60s”）
    public var renderOnInit: Bool = true
    /// 计时过程中是否允许点击
    public var clickableWhileRunning: Bool = false

    // NOTE:
    // Swift 不允许给「存储属性」标 @available。
    // 为了做到 iOS 15 以下也能编译，这里把 iOS 15 的 configuration renderer
    // 做成「计算属性 + Any 盒子存储」。对外 API 不变，你原来的调用方式不需要改。
    private var _renderConfigurationBox: Any?

    /// 渲染 UIButton.Configuration
    /// - 参数 sec: 当前秒数（向下时是“剩余秒数”，向上时是“已经走过的 step 数”）
    /// - 参数 base: 启动计时前的基础 configuration (已 copy)
    @available(iOS 15.0, *)
    public var renderConfiguration: ((Int, UIButton.Configuration) -> UIButton.Configuration)? {
        get { _renderConfigurationBox as? ((Int, UIButton.Configuration) -> UIButton.Configuration) }
        set { _renderConfigurationBox = newValue }
    }

    /// iOS 14 及以下渲染（不使用 UIButton.Configuration）
    /// - 参数 sec: 当前秒数（向下时是“剩余秒数”，向上时是“已经走过的 step 数”）
    /// - 参数 button: 直接对 UIButton 做设置（例如 setTitle / setAttributedTitle / setImage 等）
    public var renderLegacy: ((Int, UIButton) -> Void)?

    /// 每 tick 回调
    public var onTick: ((_ button: UIButton,
                         _ config: JobsCountdownBtnConfig,
                         _ sec: Int) -> Void)?
    /// 计时结束回调（已经自动复原 configuration & isEnabled）
    public var onFinish: ((_ button: UIButton,
                           _ config: JobsCountdownBtnConfig) -> Void)?

    /// 运行中被点击（仅当 clickableWhileRunning = true 时才会触发）
    public var onTapWhileRunning: ((_ button: UIButton,
                                    _ config: JobsCountdownBtnConfig) -> Void)?
    public init() { }
}
