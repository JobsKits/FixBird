//
//  MarketplaceAccountViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceAccountViewController: MarketplaceFeatureViewController {
    var registrationRole: MarketplaceRole = .customer
    private var authenticating = false
    private var confirmedEntryRole: MarketplaceRole?

    override var screenTitle: String {
        return MarketplaceSessionCenter.shared.currentRole == nil ? "选择使用身份" : "我的账号"
    }

    override var activeRole: MarketplaceRole {
        return confirmedEntryRole ?? MarketplaceSessionCenter.shared.currentRole ?? registrationRole
    }

    override func drawPage() {
        let sessions = MarketplaceSessionCenter.shared
        if let notice = sessions.notice {
            addInfo(notice.tr)
        }
        if let session = sessions.current {
            addInfo(session.user.displayName + "\n" + session.user.username + "\n" + (session.user.marketplaceRole?.displayName.tr ?? session.user.role))
            addInfo("当前账号角色由服务端决定；退出仅撤销本设备会话。".tr)
            addButton("修改我的密码".tr) { [weak self] in
                self?.presentPasswordChange()
            }
            addButton("切换身份".tr) { [weak self] in
                self?.confirmIdentitySwitch()
            }
            addButton("退出当前设备".tr) {
                MarketplaceAccountStore.shared.logout()
            }
            let target = keep(MarketplaceUIFactory.stack())
            contentStack.byAddArrangedSubview(target)
            addInfo("正在校验登录状态。".tr, to: target)
            let expected = context
            retain(MarketplaceAccountStore.shared.refreshUser { [weak self] result in
                guard let self, self.context == expected else {
                    return
                }
                target.byRemoveAllArrangedSubviews()
                switch result {
                /// 当前服务端确已认可会话。
                case .success:
                    self.addInfo("服务端已确认登录状态。".tr, to: target)
                /// 保留已安全保存的会话，但不声称本次校验成功。
                case .failure(let failure):
                    self.addInfo("本次登录校验未获确认。".tr + "\n" + failure.detail.tr, to: target)
                }
            })
        } else {
            addInfo("请先确认本次使用身份，再登录对应账号。用户下单与师傅接单分别进入独立业务首页。".tr)
            addButton("我是用户 · 预约维修".tr) { [weak self] in
                self?.selectEntryRole(.customer)
            }
            addButton("我是师傅 · 接单服务".tr) { [weak self] in
                self?.selectEntryRole(.worker)
            }
            guard let confirmedEntryRole else {
                return
            }
            addInfo("当前选择：".tr + confirmedEntryRole.displayName.tr)
            addButton("账号密码登录".tr) { [weak self] in
                self?.presentAuthentication(registering: false)
            }
            addButton(confirmedEntryRole == .customer ? "注册用户账号".tr : "注册师傅账号".tr) { [weak self] in
                self?.presentAuthentication(registering: true)
            }
            addButton("显式使用本地演示账号".tr) { [weak self] in
                guard let self else {
                    return
                }
                sessions.enterLocalDemo(role: self.registrationRole)
            }
        }
    }

    private func presentPasswordChange() {
        formAlert = UIAlertController.makeAlert("修改我的密码".tr, "修改后本账号的旧会话将失效，需要重新登录。".tr)
            .byAddTextField { field in
                field.byPlaceholder("当前密码".tr)
                    .bySecureTextEntry(true)
            }
            .byAddTextField { field in
                field.byPlaceholder("新密码（至少12个字符）".tr)
                    .bySecureTextEntry(true)
            }
            .byAddTextField { field in
                field.byPlaceholder("确认新密码".tr)
                    .bySecureTextEntry(true)
            }
            .byAddCancel("取消".tr)
            .byAddOK("修改密码".tr) { [weak self] alert, _ in
                guard let self, let fields = alert.textFields, fields.count == 3 else {
                    return
                }
                let password = fields[1].text ?? ""
                guard password.count >= 12, password.count <= 128, password.utf8.count <= 256, password == fields[2].text else {
                    self.showMessage("新密码至少12个字符，且两次输入必须一致。".tr)
                    return
                }
                let expected = self.context
                MarketplaceAccountStore.shared.changePassword(currentPassword: fields[0].text ?? "", password: password) { [weak self] result in
                    guard let self, self.context == expected else {
                        return
                    }
                    if case .failure(let failure) = result {
                        self.showMessage("密码修改未确认。".tr + "\n" + failure.detail.tr)
                    }
                }
            }
            .byPresent(self, animated: true)
    }

    private func selectEntryRole(_ selected: MarketplaceRole) {
        guard authenticating == false else {
            return
        }
        confirmedEntryRole = selected
        registrationRole = selected
        reloadPage()
    }

    private func confirmIdentitySwitch() {
        formAlert = UIAlertController.makeAlert("切换身份".tr, "将退出当前账号并返回身份选择页。请登录所选身份对应的账号；不会将用户账号直接变成师傅账号。".tr)
            .byAddCancel("取消".tr)
            .byAddOK("切换身份".tr) { _, _ in
                MarketplaceAccountStore.shared.logout()
            }
            .byPresent(self, animated: true)
    }

    private func presentAuthentication(registering: Bool) {
        guard authenticating == false else {
            return
        }
        formAlert = UIAlertController.makeAlert(registering ? "创建账号".tr : "账号密码登录".tr, "密码不会写入本地偏好或日志。".tr)
            .byAddTextField { field in
                field.byPlaceholder("账号".tr)
                    .byAutocapitalizationType(.none)
                    .byAutocorrectionType(.no)
            }
            .byAddTextField { field in
                field.byPlaceholder("密码".tr)
                    .bySecureTextEntry(true)
                    .byAutocapitalizationType(.none)
                    .byAutocorrectionType(.no)
            }
        if registering {
            formAlert?.byAddTextField { field in
                field.byPlaceholder("姓名或称呼".tr)
            }
        }
        formAlert?.byAddCancel("取消".tr)
            .byAddOK("确认".tr) { [weak self] alert, _ in
                guard let self, let fields = alert.textFields, fields.count >= 2 else {
                    return
                }
                let name = registering ? (fields.last?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let input = MarketplaceAuthInput(username: (fields[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines), password: fields[1].text ?? "", displayName: name, role: self.registrationRole)
                if let message = input.validationMessage(registering: registering) {
                    self.showMessage(message.tr)
                    return
                }
                self.authenticating = true
                let expected = self.context
                MarketplaceAccountStore.shared.authenticate(input, registering: registering) { [weak self] result in
                    guard let self else {
                        return
                    }
                    self.authenticating = false
                    /// 成功会由 Scene 切换到服务端身份；失败仍停留未登录页。
                    guard self.context == expected else {
                        return
                    }
                    if case .failure(let failure) = result {
                        self.showMessage("登录未成功，未创建本地登录状态。".tr + "\n" + failure.detail.tr)
                    }
                }
            }
            .byPresent(self, animated: true)
    }
}
