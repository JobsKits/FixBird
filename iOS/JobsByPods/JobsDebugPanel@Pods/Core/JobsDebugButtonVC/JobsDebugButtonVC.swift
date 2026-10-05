//
//  JobsDebugButtonVC.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit
import JobsInheritance
import JobsByUIKit
import JobsSwiftBaseDefines
import SnapKit

final class JobsDebugButtonVC: BaseVC {
    private var centerXConstraint: Constraint?
    private var centerYConstraint: Constraint?
    private var buttonCenter: CGPoint?
    private var dragStartCenter = CGPoint.zero

    private lazy var debugButton: UIButton = {
        UIButton.custom()
            .byBgImage(JobsDebugPanelResource.buttonImage)
            .byAccessibilityLabel("打开调试面板；可拖动；长按隐藏至下次启动")
            .onTap { [weak self] _ in
                guard let window = self?.view.window as? JobsDebugOverlayWindow,
                      let host = window.hostWindow else {
                    return
                }
                JobsDebugPanel.shared.toggle(from: host)
            }
            .onLongPress(minimumPressDuration: 0.8) { _, recognizer in
                guard recognizer.state == .began else {
                    return
                }
                JobsDebugPanel.shared.byHideForCurrentLaunch()
            }
            .addPanAction(maximumNumberOfTouches: 1) { [weak self] recognizer in
                guard let pan = recognizer as? UIPanGestureRecognizer else {
                    return
                }
                self?.moveButton(with: pan)
            }
            .byAddTo(view) { [unowned self] make in
                make.size.equalTo(56)
                centerXConstraint = make.centerX.equalTo(view.snp.left).constraint
                centerYConstraint = make.centerY.equalTo(view.snp.top).constraint
            }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.byBackgroundColor(JobsCor.clear)
        debugButton.byVisible(true)
        jobsDebugFollowTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        guard safeFrame.width > 0, safeFrame.height > 0 else {
            return
        }
        let initialCenter = CGPoint(x: safeFrame.maxX - 44, y: safeFrame.maxY - 138)
        updateButtonCenter(buttonCenter ?? initialCenter)
    }

    func updateAccessibility(isPanelOpen: Bool) {
        guard isViewLoaded else {
            return
        }
        let action = isPanelOpen ? "关闭调试面板并返回" : "打开调试面板"
        debugButton.byAccessibilityLabel(action + "；可拖动；长按隐藏至下次启动")
    }

    private func moveButton(with pan: UIPanGestureRecognizer) {
        switch pan.state {
        /// 记录手指开始移动时的位置，后续按累计位移计算。
        case .began:
            dragStartCenter = debugButton.center
        /// 移动、松手或取消时都将最终位置限制在安全区域。
        case .changed, .ended, .cancelled:
            let translation = pan.translation(in: view)
            updateButtonCenter(CGPoint(x: dragStartCenter.x + translation.x,
                                       y: dragStartCenter.y + translation.y))
            view.byLayoutIfNeeded()
        /// 尚未识别或识别失败时保持原位置。
        default:
            break
        }
    }

    private func updateButtonCenter(_ proposedCenter: CGPoint) {
        // 拖动和窗口尺寸变化都保留完整触摸区域，避免入口滑出屏幕。
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let minX = min(safeFrame.midX, safeFrame.minX + 44)
        let maxX = max(safeFrame.midX, safeFrame.maxX - 44)
        let minY = min(safeFrame.midY, safeFrame.minY + 44)
        let maxY = max(safeFrame.midY, safeFrame.maxY - 44)
        let center = CGPoint(x: min(max(proposedCenter.x, minX), maxX),
                             y: min(max(proposedCenter.y, minY), maxY))
        guard buttonCenter != center else {
            return
        }
        buttonCenter = center
        centerXConstraint?.update(offset: center.x)
        centerYConstraint?.update(offset: center.y)
    }

    func containsButton(_ point: CGPoint, from window: UIWindow) -> Bool {
        guard isViewLoaded, !debugButton.isHidden else {
            return false
        }
        let local = debugButton.convert(point, from: window)
        let radius = debugButton.bounds.width * 0.5
        let dx = local.x - debugButton.bounds.midX
        let dy = local.y - debugButton.bounds.midY
        return dx * dx + dy * dy <= radius * radius
    }
}
#endif
