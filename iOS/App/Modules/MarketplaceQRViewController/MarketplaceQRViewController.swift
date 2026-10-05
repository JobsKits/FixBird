//
//  MarketplaceQRViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceQRViewController: MarketplaceFeatureViewController {
    override var screenTitle: String {
        return "扫码登录授权"
    }
    private var login: MarketplaceQRLogin?
    private var challenge: MarketplaceQRChallenge?
    private var scanner: MarketplaceQRScanner?
    private var deciding = false
    private var inspectionFailure: String?

    override func reloadPage() {
        challenge = nil
        inspectionFailure = nil
        super.reloadPage()
    }

    override func drawPage() {
        scanner?.byStop()
        scanner = nil
        addInfo("扫描电脑登录二维码，先核对设备与到期时间，再明确批准或拒绝。".tr)
        addInfo("电脑授权不会退出手机；扫码电脑会话不能管理设备或再授权扫码。".tr)
        let canAuthorize = MarketplaceSessionCenter.shared.current?.session?.capabilities.contains("authorize_qr") == true
        if canAuthorize == false {
            addInfo("扫码授权需要手机上的账号密码登录。".tr)
        }
        addButton("打开相机扫码".tr) { [weak self] in
            self?.startScanner()
        }
        addButton("粘贴或输入二维码内容".tr) { [weak self] in
            self?.presentURIForm()
        }
        if let challenge {
            addInfo(challenge.device.label + "\n" + challenge.device.platform + "\n" + "到期：%@".tr(challenge.expiresAt))
            addInfo("只有你本人正在操作这台电脑时才批准。".tr)
            addButton("批准这台电脑登录".tr, enabled: canAuthorize && challenge.mayConfirm) { [weak self] in
                self?.confirmDecision(approve: true)
            }
            addButton("拒绝这台电脑登录".tr, enabled: canAuthorize && challenge.mayConfirm) { [weak self] in
                self?.confirmDecision(approve: false)
            }
        } else if let inspectionFailure {
            addInfo("扫码信息未获服务端确认；没有批准任何登录。".tr + "\n" + inspectionFailure)
        } else if let login {
            addInfo("正在向服务端核对电脑信息。".tr)
            let expected = context
            retain(MarketplaceQRStore.shared.inspect(login, role: activeRole) { [weak self] result in
                guard let self, self.context == expected else {
                    return
                }
                switch result {
                /// 仅展示信息，绝不在 inspect 后自动授权。
                case .success(let challenge):
                    self.challenge = challenge
                /// 保留可重新扫描入口，不能伪造已确认的电脑。
                case .failure(let failure):
                    self.inspectionFailure = failure.detail.tr
                }
                self.redraw()
            })
        } else {
            addEmpty("尚未扫描登录二维码".tr)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner?.byStop()
    }

    private func redraw() {
        super.reloadPage()
    }

    private func acceptURI(_ text: String) {
        guard let login = MarketplaceQRLogin(uri: text) else {
            showMessage("二维码格式无效，请扫描本平台电脑登录二维码。".tr)
            return
        }
        self.login = login
        challenge = nil
        inspectionFailure = nil
        redraw()
    }

    private func presentURIForm() {
        formAlert = UIAlertController.makeAlert("粘贴或输入二维码内容".tr, "只读取本平台登录地址；不会自动授权。".tr)
            .byAddTextField { field in
                field.byPlaceholder("repairmarketplace://login?..." )
                    .byText(UIPasteboard.general.string)
                    .byAutocapitalizationType(.none)
                    .byAutocorrectionType(.no)
            }
            .byAddCancel("取消".tr)
            .byAddOK("核对电脑信息".tr) { [weak self] alert, _ in
                self?.acceptURI(alert.textFields?.first?.text ?? "")
            }
            .byPresent(self, animated: true)
    }

    private func startScanner() {
        scanner?.byStop()
        let expected = context
        let scanner = keep(MarketplaceQRScanner.make()
            .byScanned { [weak self] text in
                guard let self, self.context == expected else {
                    return
                }
                self.acceptURI(text)
            }
            .byFailure { [weak self] key in
                self?.showMessage(key.tr)
            })
        self.scanner = scanner
        contentStack.byAddArrangedSubview(scanner)
        scanner.snp.makeConstraints { make in
            make.height.equalTo(300)
        }
        scanner.byStart()
    }

    private func confirmDecision(approve: Bool) {
        guard deciding == false, let login, let challenge, challenge.mayConfirm else {
            return
        }
        formAlert = UIAlertController.makeAlert(approve ? "批准这台电脑登录".tr : "拒绝这台电脑登录".tr, challenge.device.label + "\n" + challenge.device.platform + "\n" + "到期：%@".tr(challenge.expiresAt))
            .byAddCancel("取消".tr)
            .byAddOK("确认".tr) { [weak self] _, _ in
                guard let self else {
                    return
                }
                self.deciding = true
                let expected = self.context
                MarketplaceQRStore.shared.decide(login, approve: approve, role: self.activeRole) { [weak self] result in
                    guard let self else {
                        return
                    }
                    self.deciding = false
                    guard self.context == expected else {
                        return
                    }
                    switch result {
                    /// 服务端明确处理后才显示授权结果。
                    case .success(let decision):
                        self.login = nil
                        self.challenge = nil
                        self.inspectionFailure = nil
                        self.redraw()
                        self.showMessage(decision.status == "approved" ? "电脑已获授权，手机保持登录。".tr : "已拒绝这次电脑登录。".tr)
                    /// 超时或拒绝都不能假装电脑已获授权。
                    case .failure(let failure):
                        self.showMessage("授权结果未获服务端确认；请核对电脑状态，不会自动重试。".tr + "\n" + failure.detail.tr)
                    }
                }
            }
            .byPresent(self, animated: true)
    }
}
