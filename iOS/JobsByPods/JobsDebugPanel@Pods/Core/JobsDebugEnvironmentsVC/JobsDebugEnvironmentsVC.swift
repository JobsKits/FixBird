//
//  JobsDebugEnvironmentsVC.swift
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

final class JobsDebugEnvironmentsVC: BaseVC, UITableViewDataSource, UITableViewDelegate {
    private lazy var tableView: UITableView = {
        UITableView.jobsMake { table in
            table
                .byDataSource(self)
                .byDelegate(self)
                .byRowHeight(82)
                .byBackgroundColor(JobsCor.systemBackground)
                .byEmptyButtonProvider { [weak self] in
                    JobsEmptyAuto.Config.defaultProvider()
                        .byTitle("尚未配置有效的网络环境")
                        .bySubTitle("请在 AppDelegate 配置 URL；点此重新加载")
                        .onTap { [weak self] _ in
                            self?.tableView.byReloadData().byReloadEmptyViewAuto()
                        }
                }
                .byAddTo(view) { [unowned self] make in
                    make.top.equalTo(gk_navigationBar.snp.bottom)
                    make.left.right.bottom.equalToSuperview()
                }
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "选择网络环境")
        tableView.byVisible(true)
        jobsDebugFollowTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.byReloadEmptyViewAuto()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return JobsDebugPanel.shared.environments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let panel = JobsDebugPanel.shared
        let environment = panel.environments[indexPath.row]
        return UITableViewCell.make(style: .subtitle, reuseIdentifier: "EnvironmentChoice")
            .byText(environment.remark.isEmpty ? environment.urlString : environment.remark)
            .bySecondaryText(environment.urlString)
            .byContentConfiguration { configuration in
                configuration.secondaryTextProperties.numberOfLines = 2
            }
            .byTitleCor(JobsCor.label)
            .byDetailTitleCor(JobsCor.secondaryLabel)
            .byBackgroundColor(JobsCor.systemBackground)
            .byTintColor(JobsCor.label)
            .bySelectedBackgroundView(UIView.jobsMake { $0.byBackgroundColor(JobsCor.secondarySystemBackground) })
            .byAccessoryType(environment === panel.selectedEnvironment ? .checkmark : .none)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        JobsDebugPanel.shared.select(JobsDebugPanel.shared.environments[indexPath.row])
        tableView
            .byDeselectRow(indexPath)
            .byReloadData()
    }
}
#endif
