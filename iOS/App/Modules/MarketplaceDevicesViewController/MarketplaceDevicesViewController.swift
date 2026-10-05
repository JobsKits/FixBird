//
//  MarketplaceDevicesViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceDevicesViewController: MarketplaceFeatureViewController {
    private var revoking: Set<String> = []
    override var screenTitle: String {
        return "登录设备"
    }

    override func drawPage() {
        addInfo("手机退出只影响本设备；电脑和其他手机可以继续登录。".tr)
        let canManage = MarketplaceSessionCenter.shared.current?.session?.capabilities.contains("manage_devices") == true
        if canManage == false {
            addInfo("设备管理需要手机上的账号密码会话；扫码电脑会话不具备管理权限。".tr)
        }
        let target = keep(MarketplaceUIFactory.stack())
        contentStack.byAddArrangedSubview(target)
        populate(MarketplaceDeviceStore.shared.preview(role: activeRole), in: target, canManage: canManage)
        let expected = context
        retain(MarketplaceDeviceStore.shared.fetch(role: activeRole) { [weak self] outcome in
            guard let self, self.context == expected else {
                return
            }
            self.populate(outcome, in: target, canManage: canManage)
        })
    }

    private func populate(_ outcome: MarketplaceOutcome<[MarketplaceDeviceSession]>, in target: UIStackView, canManage: Bool) {
        target.byRemoveAllArrangedSubviews()
        addInfo(sourceText(outcome), to: target)
        guard outcome.value.isEmpty == false else {
            addEmpty("暂无可确认的登录设备".tr, to: target)
            return
        }
        for device in outcome.value {
            let current = device.isCurrent == true ? "当前设备".tr : "其他设备".tr
            addInfo(device.device.label + " · " + device.device.platform + "\n" + current + "\n" + "到期：%@".tr(device.expiresAt), to: target)
            let button = keep(MarketplaceUIFactory.button("撤销此设备登录".tr) { [weak self] in
                self?.confirmRevocation(device)
            }.byEnabled(canManage && outcome.source == .server))
            target.byAddArrangedSubview(button)
        }
    }

    private func confirmRevocation(_ device: MarketplaceDeviceSession) {
        guard revoking.contains(device.id) == false else {
            return
        }
        formAlert = UIAlertController.makeAlert("撤销此设备登录".tr, device.device.label + "\n" + device.device.platform + "\n" + "只撤销所选设备，其他设备继续有效。".tr)
            .byAddCancel("取消".tr)
            .byAddOK("确认撤销".tr) { [weak self] _, _ in
                guard let self else {
                    return
                }
                self.revoking.insert(device.id)
                let expected = self.context
                MarketplaceDeviceStore.shared.revoke(device.id, role: self.activeRole) { [weak self] result in
                    guard let self else {
                        return
                    }
                    self.revoking.remove(device.id)
                    guard self.context == expected else {
                        return
                    }
                    switch result {
                    /// 本设备撤销后清本机 Keychain；其他设备不受影响。
                    case .success:
                        if device.isCurrent == true {
                            MarketplaceSessionCenter.shared.clear(notice: "本设备登录已撤销，其他设备继续有效。")
                        } else {
                            self.reloadPage()
                            self.showMessage("所选设备已撤销，其他设备继续有效。".tr)
                        }
                    /// 失败不假装会话已被撤销，也不自动重放。
                    case .failure(let failure):
                        self.showMessage("设备撤销未获服务端确认；不会自动重试。".tr + "\n" + failure.detail.tr)
                    }
                }
            }
            .byPresent(self, animated: true)
    }
}
