//
//  MarketplaceWorkerViewController.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import Jobsl10n

final class MarketplaceWorkerViewController: MarketplaceFeatureViewController {
    override var screenTitle: String {
        return "师傅资料与审核"
    }
    override var activeRole: MarketplaceRole {
        return .worker
    }
    private var draft = MarketplaceWorkerDraft()
    private var draftChanged = false
    private var submitting = false
    private var uploading = false
    private var picker: UIImagePickerController?
    private var selectedImage: UIImage?
    private var lastDemoSubmission: MarketplaceOutcome<MarketplaceWorkerApplication?>?

    override func drawPage() {
        addInfo("提交资料及资质图片，由后台人工审核；审核通过后方可接单。".tr)
        addInfo("修改已通过的资料并重提后，会重新等待审核。".tr)
        let target = keep(MarketplaceUIFactory.stack())
        contentStack.byAddArrangedSubview(target)
        populate(MarketplaceWorkerStore.shared.preview(), in: target)
        addButton("编辑师傅资料".tr) { [weak self] in
            self?.presentProfileForm()
        }
        addButton("放弃未提交编辑并重新读取资料".tr) { [weak self] in
            self?.draftChanged = false
            self?.selectedImage = nil
            self?.lastDemoSubmission = nil
            self?.reloadPage()
        }
        addButton("选择并上传资质图片".tr) { [weak self] in
            self?.choosePhoto()
        }
        addButton("移除草稿图片并重新上传".tr) { [weak self] in
            self?.draft.assetIds = []
            self?.selectedImage = nil
            self?.draftChanged = true
            self?.reloadPage()
        }
        addButton("提交人工审核".tr) { [weak self] in
            self?.submitDraft()
        }
        let expected = context
        retain(MarketplaceWorkerStore.shared.fetch { [weak self] outcome in
            guard let self, self.context == expected else {
                return
            }
            self.populate(outcome, in: target)
        })
    }

    private func populate(_ outcome: MarketplaceOutcome<MarketplaceWorkerApplication?>, in target: UIStackView) {
        target.byRemoveAllArrangedSubviews()
        addInfo(sourceText(outcome), to: target)
        if draftChanged == false {
            draft = MarketplaceWorkerDraft(application: outcome.value)
        }
        if let application = outcome.value {
            let title = outcome.source == .demo ? "本地待审核演示，尚未提交到平台。".tr : application.statusTitle.tr
            addInfo(title + "\n" + application.displayName + "\n" + application.contactPhone, to: target)
            addInfo(application.serviceAreas.joined(separator: "、") + "\n" + application.skills.joined(separator: "、") + "\n" + application.bio, to: target)
            if application.reviewNote.isEmpty == false {
                addInfo("审核说明：%@".tr(application.reviewNote), to: target)
            }
        } else {
            addEmpty("尚未提交师傅资料".tr, to: target)
        }
        if draftChanged {
            addInfo("未提交草稿".tr + "\n" + draft.displayName + "\n" + draft.contactPhone, to: target)
        }
        addInfo("资质图片：%d / 6".tr(draft.assetIds.count), to: target)
        if let selectedImage {
            appendImage(selectedImage, to: target)
        }
        for (index, id) in draft.assetIds.enumerated() {
            let button = keep(MarketplaceUIFactory.button("查看私有资质图片%d".tr(index + 1)) { [weak self] in
                self?.loadPrivateImage(id)
            })
            target.byAddArrangedSubview(button)
        }
        if let lastDemoSubmission {
            addInfo("本地演示结果（不会同步）".tr + "\n" + sourceText(lastDemoSubmission), to: target)
        }
    }

    private func appendImage(_ image: UIImage, to target: UIStackView) {
        let imageView = keep(UIImageView.jobsMake { imageView in
            imageView.byImage(image)
                .byContentMode(.scaleAspectFit)
                .byClipsToBounds(true)
        })
        target.byAddArrangedSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.height.equalTo(180)
        }
    }

    private func loadPrivateImage(_ id: String) {
        let expected = context
        retain(MarketplaceWorkerStore.shared.image(assetID: id) { [weak self] result in
            guard let self, self.context == expected else {
                return
            }
            switch result {
            /// 私有图片只在当前页面内存显示。
            case .success(let data):
                guard data.count <= 5 * 1024 * 1024, let image = UIImage.make(data: data) else {
                    self.showMessage("私有图片无法解析，请重新上传。".tr)
                    return
                }
                self.selectedImage = image
                self.reloadPage()
            /// 保留页面及草稿，不公开任何图片 URL。
            case .failure(let failure):
                self.showMessage("私有图片读取未获确认。".tr + "\n" + failure.detail.tr)
            }
        })
    }

    private func presentProfileForm() {
        let placeholders = ["姓名或称呼", "联系方式", "服务区域（逗号分隔）", "维修技能（逗号分隔）", "个人简介（可选）"]
        let values = [draft.displayName, draft.contactPhone, draft.serviceAreas.joined(separator: ","), draft.skills.joined(separator: ","), draft.bio]
        formAlert = UIAlertController.makeAlert("编辑师傅资料".tr)
        for index in placeholders.indices {
            formAlert?.byAddTextField { field in
                field.byPlaceholder(placeholders[index].tr)
                    .byText(values[index])
            }
        }
        formAlert?.byAddCancel("取消".tr)
            .byAddOK("保存草稿".tr) { [weak self] alert, _ in
                guard let self, let fields = alert.textFields, fields.count == 5 else {
                    return
                }
                let values = fields.map { ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
                self.draft.displayName = values[0]
                self.draft.contactPhone = values[1]
                self.draft.serviceAreas = MarketplaceWorkerDraft.items(from: values[2])
                self.draft.skills = MarketplaceWorkerDraft.items(from: values[3])
                self.draft.bio = values[4]
                self.draftChanged = true
                self.reloadPage()
            }
            .byPresent(self, animated: true)
    }

    private func choosePhoto() {
        guard uploading == false, draft.assetIds.count < 6 else {
            showMessage("最多上传6张图片；可移除草稿图片后重新选择。".tr)
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showMessage("当前设备无法打开相册。".tr)
            return
        }
        picker = UIImagePickerController.jobsMake { picker in
            picker.bySourceType(.photoLibrary)
                .byTarget(self)
                .didFinishPickingMediaWithInfo { [weak self] _, picker, info in
                    picker.byDismiss(animated: true) {
                        guard let image = info[.originalImage] as? UIImage else {
                            return
                        }
                        self?.upload(image)
                    }
                }
                .didCancel { _, picker in
                    picker.byDismiss(animated: true)
                }
        }
        picker?.byPresent(self, animated: true)
    }

    private func upload(_ image: UIImage) {
        uploading = true
        selectedImage = image
        let expected = context
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = image.marketplaceQualificationJPEG(maxBytes: 2 * 1024 * 1024)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard self.context == expected else {
                    self.uploading = false
                    return
                }
                guard let data, data.count <= 2 * 1024 * 1024 else {
                    self.uploading = false
                    self.showMessage("图片须压缩到2MiB以内。".tr)
                    return
                }
                self.retain(MarketplaceWorkerStore.shared.upload(data) { [weak self] outcome in
                    guard let self else {
                        return
                    }
                    self.uploading = false
                    guard self.context == expected else {
                        return
                    }
                    if let asset = outcome.value {
                        self.draft.assetIds.append(asset.id)
                        self.draftChanged = true
                    }
                    self.reloadPage()
                    self.showMessage(outcome.source == .server ? "资质图片已上传，提交资料后由后台审核。".tr : self.sourceText(outcome))
                })
            }
        }
    }

    private func submitDraft() {
        guard submitting == false else {
            return
        }
        if let message = draft.validationMessage {
            showMessage(message.tr)
            return
        }
        submitting = true
        let expected = context
        MarketplaceWorkerStore.shared.submit(draft) { [weak self] outcome in
            guard let self else {
                return
            }
            self.submitting = false
            guard self.context == expected else {
                return
            }
            self.lastDemoSubmission = outcome.source == .demo ? outcome : nil
            if outcome.source == .server {
                self.draft = MarketplaceWorkerDraft(application: outcome.value)
                self.draftChanged = false
            }
            self.reloadPage()
            self.showMessage(outcome.source == .server ? "资料已提交，等待后台人工审核。".tr : self.sourceText(outcome))
        }
    }
}
