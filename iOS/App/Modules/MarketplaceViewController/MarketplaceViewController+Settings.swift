//
//  MarketplaceViewController+Settings.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines
import JobsSwiftSplash
import Jobsl10n

extension MarketplaceViewController {
    func renderSettings() {
        connectionLabel.byText("偏好设置".tr)
        let profile = keep(MarketplaceUIFactory.button(
            (MarketplaceSessionCenter.shared.current?.user.displayName ?? "本地演示账号".tr) + " · " + role.displayName.tr + "　›"
        ) { [weak self] in
            guard let self else {
                return
            }
            let controller = MarketplaceAccountViewController()
            controller.registrationRole = self.role
            self.navigationController?.pushViewControllerByAnimated(controller)
        }
            .byImage(UIImage.make(named: "RepairLogo"))
            .byAccessibilityLabel("头像 · 我的账号与身份切换".tr))
        contentStack.byAddArrangedSubview(profile)
        if MarketplaceSessionCenter.shared.isLocalDemo {
            addActionCard(title: "切换身份".tr, detail: "返回身份选择页，再选择用户或师傅。".tr) {
                MarketplaceSessionCenter.shared.clear(notice: "请选择新的使用身份。")
            }
        }
        if let notice = MarketplaceSessionCenter.shared.notice {
            addInfoCard(notice.tr)
        }
        addActionCard(title: "登录设备".tr, detail: "手机管理本人设备；退出仅影响当前设备。".tr) { [weak self] in
            self?.navigationController?.pushViewControllerByAnimated(MarketplaceDevicesViewController())
        }
        addActionCard(title: "扫码登录授权".tr, detail: "先查看电脑信息，再明确批准或拒绝。".tr) { [weak self] in
            self?.navigationController?.pushViewControllerByAnimated(MarketplaceQRViewController())
        }
        if role == .worker {
            addActionCard(title: "师傅资料与审核".tr, detail: "上传资料和图片，查看人工审核结果。".tr) { [weak self] in
                self?.navigationController?.pushViewControllerByAnimated(MarketplaceWorkerViewController())
            }
            addActionCard(title: "我的账务与分润".tr, detail: "查询本人模拟收款、分润与人工核销流水。".tr) { [weak self] in
                self?.navigationController?.pushViewControllerByAnimated(MarketplaceLedgerViewController())
            }
        }
        addSectionTitle("偏好设置".tr)
        let themeTitle = JobsThemeCenter.shared.isDarkMode ? "切换浅色主题".tr : "切换深色主题".tr
        addActionCard(title: themeTitle, detail: "主题选择会保存在本机。".tr) {
            JobsThemeCenter.shared.setStyle(JobsThemeCenter.shared.isDarkMode ? .light : .dark)
        }
        let languageTitle = LanguageManager.shared.currentLanguageCode.hasPrefix("zh") ? "Switch to English" : "切换为简体中文"
        addActionCard(title: languageTitle, detail: "当前：%@".tr(LanguageManager.shared.currentLanguageCode)) {
            LanguageManager.shared.switchTo(LanguageManager.shared.currentLanguageCode.hasPrefix("zh") ? "en" : "zh-Hans")
        }
        #if DEBUG
        addActionCard(title: "配置服务地址".tr, detail: MarketplaceAPI.shared.baseURLString) { [weak self] in
            guard let self else {
                return
            }
            MarketplaceDebugPanel.presentAddressEditor(from: self)
        }
        #endif
        let splashTitle = JobsSplashPreferences.isEnabledForNextLaunch ? "下次启动跳过开屏".tr : "下次启动展示开屏".tr
        addActionCard(title: splashTitle, detail: "基于 JobsSwiftSplash，本地素材不请求网络。".tr) { [weak self] in
            JobsSplashPreferences.toggleForNextLaunch()
            self?.render()
        }
        addInfoCard("付款渠道暂未接入。订单与分润流程可在演示环境中验证，不会真实扣款或转账。".tr)
        addInfoCard("真实账号使用服务端角色；未登录时可体验独立本地演示。".tr)
    }
}
