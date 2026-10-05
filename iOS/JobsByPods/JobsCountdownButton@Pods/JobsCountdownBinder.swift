//
//  JobsCountdownBinder.swift
//  JobsCountdownButton
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftTimer
import JobsSwiftBaseDefines

// MARK: - ✅ 新版 JobsSwiftTimer：给任意 UIButton 挂一个倒计时驱动
public final class JobsCountdownBinder {
    private weak var button: UIButton?
    private var timer: JobsSwiftTimerProtocol?

    private var total: Int = 0
    private var remain: Int = 0
    private var interval: TimeInterval = 1.0
    private var kind: JobsTimerKind = .gcd

    deinit {
        timer?.stop()
        timer = nil
    }

    @MainActor
    public func start(on button: UIButton,
                      total: Int,
                      interval: TimeInterval,
                      kind: JobsTimerKind) {
        stop()
        self.button = button
        self.total = max(1, total)
        self.remain = self.total
        self.interval = max(0.000_001, interval)
        self.kind = kind
        // 先把 UI 初始化成 “还剩 xxxs”
        applyUI(remain: self.remain, total: self.total, kind: kind)
        let cfg = JobsSwiftTimerConfig(
            interval: self.interval,
            repeats: true,
            tolerance: 0,
            queue: .main,
            runLoop: .main,
            runLoopMode: .common,
            pauseInBackground: true,
            autoManageAppState: true
        )
        let t = JobsTimer(kind: kind, config: cfg) { [weak self] in
            // ✅ Swift 6 / Sendable 同等待遇：先冻结 self，再切 MainActor
            guard let strongSelf = self else { return }
            onMainAsync(self) { vc in
                guard let btn = strongSelf.button else {
                    strongSelf.stop()
                    return
                }
                strongSelf.remain -= 1
                let remain = max(0, strongSelf.remain)
                print("⏱️ [\(strongSelf.kind.displayName)] \(remain)/\(strongSelf.total)")
                if remain <= 0 {
                    print("✅ [\(strongSelf.kind.displayName)] 倒计时完成")
                    strongSelf.stop()
                    // 完成态 UI
                    btn.byTitle("活动".tr, for: .normal)
                        .byTitle("活动".tr, for: .selected)
                        .bySubTitle("倒计时".tr, for: .normal)
                        .bySubTitle("倒计时".tr, for: .selected)
                        .byUpdateConfig()
                    return
                }
                strongSelf.applyUI(remain: remain,
                                   total: strongSelf.total,
                                   kind: strongSelf.kind)
            }
        }
        timer = t
        t.start()
    }

    @MainActor
    public func stop() {
        timer?.stop()
        timer = nil
    }

    @MainActor
    private func applyUI(remain: Int,
                         total: Int,
                         kind: JobsTimerKind) {
        guard let btn = button else { return }
        // 你原逻辑：主标题固定“还剩”，副标题显示剩余秒数
        btn.byTitle("还剩".tr, for: .normal)
            .byTitle("还剩".tr, for: .selected)
            .bySubTitle("\(remain)s", for: .normal)
            .bySubTitle("\(remain)s", for: .selected)
            .byUpdateConfig()
    }
}
