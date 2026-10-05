//
//  MarketplaceDebugPanel.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit
import JobsDebugPanel
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

@MainActor
enum MarketplaceDebugPanel {
    static func start() {
        JobsDebugPanel.shared
            .byEnvironments(environments())
            .byEnvironmentDidChange { environment in
                guard let selected = MarketplaceEnvironment(rawValue: environment.identifier),
                      MarketplaceEnvironment.current != selected else {
                    return
                }
                MarketplaceEnvironment.select(selected)
            }
            .byAddAction(
                JobsDebugAction()
                    .byTitle("修改本机测试地址".tr)
                    .byAction { source in
                        presentAddressEditor(from: source)
                    }
            )
            .byAddAction(
                JobsDebugAction()
                    .byTitle("查看当前环境".tr)
                    .byAction { source in
                        let url = MarketplaceEnvironment.baseURLString
                        let message = MarketplaceEnvironment.current.title.tr + "\n"
                            + (url.isEmpty ? "未配置，使用本地演示".tr : url)
                        UIAlertController.makeAlert("当前网络环境".tr, message)
                            .byAddAction(title: "知道了".tr)
                            .byPresent(source, animated: true)
                    }
            )
            .byAddAction(
                JobsDebugAction()
                    .byTitle("线上配置状态".tr)
                    .byAction { source in
                        let url = MarketplaceEnvironment.productionBaseURL
                        UIAlertController.makeAlert(
                            url.isEmpty ? "线上地址未配置".tr : "线上配置状态".tr,
                            url.isEmpty
                                ? "productionBaseURL 保留为空；Release 使用本地演示，配置真实线上 URL 后才会请求服务端。".tr
                                : url
                        )
                            .byAddAction(title: "知道了".tr)
                            .byPresent(source, animated: true)
                    }
            )
            .byStart()
    }

    static func presentAddressEditor(from host: UIViewController) {
        UIAlertController.makeAlert(
            "修改本机测试地址".tr,
            "模拟器可使用 http://127.0.0.1:8080；真机填写 Mac 的局域网 IP。".tr
        )
            .byAddTextField { field in
                field
                    .byText(MarketplaceEnvironment.testBaseURL)
                    .byKeyboardType(.URL)
                    .byAutocapitalizationType(.none)
                    .byAutocorrectionType(.no)
            }
            .byAddCancel("取消".tr)
            .byAddOK("保存并刷新".tr) { [weak host] alert, _ in
                guard let value = alert.textFields?.first?.text,
                      let normalized = MarketplaceEnvironment.normalizedBaseURL(value) else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak host] in
                        guard let host, host.viewIfLoaded?.window != nil else {
                            return
                        }
                        UIAlertController.makeAlert(
                            "地址格式不正确".tr,
                            "请输入 http(s)://主机:端口，不包含接口路径、账号或查询参数。".tr
                        )
                            .byAddOK("确定".tr)
                            .byPresent(host, animated: true)
                    }
                    return
                }
                // 既有环境入口统一负责 revision、缓存隔离和旧响应保护。
                MarketplaceEnvironment.select(.test, testURL: normalized)
                JobsDebugPanel.shared.byEnvironments(environments())
            }
            .byPresent(host, animated: true)
    }

    private static func environments() -> [JobsDebugEnvironment] {
        var result = [
            JobsDebugEnvironment()
                .byIdentifier(MarketplaceEnvironment.test.rawValue)
                .byTitle(MarketplaceEnvironment.test.title.tr)
                .byBaseURL(MarketplaceEnvironment.testBaseURL)
        ]
        if let productionURL = MarketplaceEnvironment.normalizedBaseURL(MarketplaceEnvironment.productionBaseURL) {
            result.append(
                JobsDebugEnvironment()
                    .byIdentifier(MarketplaceEnvironment.production.rawValue)
                    .byTitle(MarketplaceEnvironment.production.title.tr)
                    .byBaseURL(productionURL)
            )
        }
        return result
    }
}
#endif
