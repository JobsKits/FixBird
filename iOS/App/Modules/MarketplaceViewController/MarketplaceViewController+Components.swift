//
//  MarketplaceViewController+Components.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines
import JobsImageTools
import Jobsl10n

extension MarketplaceViewController {
    func addSectionTitle(_ title: String) {
        contentStack.byAddArrangedSubview(keep(MarketplaceUIFactory.label(title, size: 19, weight: .bold)))
    }

    func addInfoCard(_ text: String) {
        let card = keep(MarketplaceUIFactory.card())
        keep(MarketplaceUIFactory.label(text))
            .byAddTo(card) { make in
                make.edges.equalToSuperview().inset(14)
            }
        contentStack.byAddArrangedSubview(card)
    }

    func addActionCard(title: String, detail: String, action: @escaping () -> Void) {
        contentStack.byAddArrangedSubview(keep(MarketplaceUIFactory.button(title + "\n" + detail, action: action)))
    }

    func addEmptyStateButton(_ subtitle: String, to target: UIStackView) {
        let button = keep(JobsEmptyAuto.Config.defaultProvider()
            .byTitle("暂无数据".tr)
            .bySubTitle(subtitle, for: .normal)
            .byImage(UIImage.make(named: "RepairLogo"))
            .byImagePlacement(.top)
            .onTap { [weak self] _ in
                self?.render()
            })
        target.byAddArrangedSubview(button)
        if let token = loadLogo(into: button) {
            logoTokens.append(token)
        }
    }

    func loadLogo(into button: UIButton) -> JobsImageLoadToken? {
        guard let url = URL(string: "https://img.alicdn.com/imgextra/i4/O1CN01XZe8pH1USpiUNT1QN_!!6000000002517-2-tps-114-114.png") else {
            return nil
        }
        return JobsImageLoader.shared.load(.remote(url), options: JobsImageLoadOptions(targetSize: CGSize(width: 56, height: 56))) { [weak button] result in
            guard case .success(let image) = result else {
                return
            }
            button?.byImage(image.image)
        }
    }

    func connectionText<Value>(_ outcome: MarketplaceOutcome<Value>) -> String {
        switch outcome.source {
        /// 本次请求确已获得服务端数据。
        case .server:
            return "服务器已连接".tr
        /// 首屏暂用上次成功快照。
        case .snapshot:
            return "正在请求服务端；先显示上次快照".tr
        /// 本地演示必须显式区分拒绝与未知。
        case .demo:
            guard let failure = outcome.failure else {
                return "正在请求服务端；先显示本机样例".tr
            }
            switch failure.kind {
            /// 服务端明确拒绝，不假装已提交。
            case .rejected:
                return "服务端拒绝（%@）；显示独立本地演示".tr(failure.statusCode.map(String.init) ?? "—")
            /// 未能连接服务或地址未配置。
            case .unavailable:
                return "离线演示：使用本机数据".tr
            /// 服务端可能已完成写操作。
            case .unknown:
                return "请求结果未知；本地演示不会自动同步".tr
            }
        }
    }

    func writeMessage(_ outcome: MarketplaceOutcome<RepairOrder?>) -> String {
        guard outcome.source == .demo, let failure = outcome.failure else {
            return "订单状态已更新。".tr
        }
        switch failure.kind {
        /// 明确呈现拒绝原因与演示边界。
        case .rejected:
            return "服务端拒绝（%@）：%@\n以下仅为本地演示，不会自动同步。".tr(failure.statusCode.map(String.init) ?? "—", failure.detail)
        /// 本地演示仍可继续体验。
        case .unavailable:
            return "服务不可用；以下仅为本地演示，不会自动同步。".tr
        /// 网络超时不能推断未创建真实订单。
        case .unknown:
            return "服务端结果未知；请先核实订单。以下仅为本地演示，不会自动同步。".tr
        }
    }

    func showMessage(_ message: String) {
        messageAlert = UIAlertController.makeAlert("提示".tr, message)
            .byAddOK("知道了".tr)
        TRBind.consumeMarkerIfNeeded()
        let context = requestContext
        /// 等提交表单的系统关闭动画结束，避免快速失败时连续 present。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.requestContext == context,
                  self.viewIfLoaded?.window != nil, self.presentedViewController == nil else {
                return
            }
            self.messageAlert?.byPresent(self, animated: true)
        }
    }
}
