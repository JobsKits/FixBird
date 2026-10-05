//
//  JobsDebugMenuVC.swift
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

final class JobsDebugMenuVC: BaseVC, UITableViewDataSource, UITableViewDelegate {
    private lazy var tableView: UITableView = {
        UITableView.jobsMake { table in
            table
                .byDataSource(self)
                .byDelegate(self)
                .byRowHeight(72)
                .byBackgroundColor(JobsCor.systemBackground)
                .byAddTo(view) { [unowned self] make in
                    make.top.equalTo(gk_navigationBar.snp.bottom)
                    make.left.right.bottom.equalToSuperview()
                }
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "调试面板")
        tableView.byVisible(true)
        jobsDebugFollowTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.byReloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        JobsDebugPanel.shared.refreshFloatingButtonAccessibility()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        JobsDebugPanel.shared.refreshFloatingButtonAccessibility()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return JobsDebugPanel.shared.actions.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return UITableViewCell.make(style: .subtitle, reuseIdentifier: "Environment")
                .byText("App 环境切换")
                .bySecondaryText(JobsDebugPanel.shared.selectedEnvironment?.remark ?? "尚未配置环境")
                .byTitleCor(JobsCor.label)
                .byDetailTitleCor(JobsCor.secondaryLabel)
                .byBackgroundColor(JobsCor.systemBackground)
                .byTintColor(JobsCor.label)
                .bySelectedBackgroundView(UIView.jobsMake { $0.byBackgroundColor(JobsCor.secondarySystemBackground) })
                .byAccessoryType(.disclosureIndicator)
        }
        let action = JobsDebugPanel.shared.actions[indexPath.row - 1]
        return UITableViewCell.make(style: .default, reuseIdentifier: "Action")
            .byText(action.title)
            .byImage(action.image)
            .byTitleCor(JobsCor.label)
            .byBackgroundColor(JobsCor.systemBackground)
            .byTintColor(JobsCor.label)
            .bySelectedBackgroundView(UIView.jobsMake { $0.byBackgroundColor(JobsCor.secondarySystemBackground) })
            .byAccessoryType(.disclosureIndicator)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.byDeselectRow(indexPath)
        if indexPath.row == 0 {
            navigationController?.pushViewControllerByAnimated(JobsDebugEnvironmentsVC())
        } else {
            JobsDebugPanel.shared.actions[indexPath.row - 1].action?(self)
        }
    }
}
#endif
