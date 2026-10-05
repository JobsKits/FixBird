//
//  JobsBaseObserver.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

// MARK: - 核心观察者（同时服务 UITextField / UITextView）
public final class JobsTextInputObserver: NSObject,
                                          UITextFieldDelegate,
                                          UITextViewDelegate {
    // 限制（nil = 不限制）
    public var limit: Int?
    // 输入回调：(当前输入字符, 当前控件值, 输入模式, 是否限制输入)
    public var onInput: ((String, String, JobsTextInputMode, Bool) -> Void)?
    // 激活/失活回调：(当前控件值)
    public var onBegin: ((String) -> Void)?
    public var onEnd: ((String) -> Void)?
    // 原 delegate（如果你外面自己设过 delegate，这里尽量转发）
    public weak var originalTextFieldDelegate: UITextFieldDelegate?
    public weak var originalTextViewDelegate: UITextViewDelegate?
    // MARK: - UITextFieldDelegate
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let allow = originalTextFieldDelegate?.textFieldShouldBeginEditing?(textField) ?? true
        return allow
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        onBegin?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidBeginEditing?(textField)
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        onEnd?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidEndEditing?(textField)
    }

    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        onEnd?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidEndEditing?(textField, reason: reason)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // 这里不是输入字符事件（真正的输入判定走 shouldChange），但保持 delegate 转发
        return originalTextFieldDelegate?.textFieldShouldReturn?(textField) ?? true
    }

    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let old = textField.text ?? ""
        let new = (old as NSString).replacingCharacters(in: range, with: string)
        // 输入模式判定
        let mode: JobsTextInputMode = {
            if string == " " { return .space }
            if string == "\n" { return .return }
            if string.isEmpty, range.length > 0 { return .delete };return .normal
        }()
        // char 规则：删除/回车 -> ""
        let char: String = (mode == .delete || mode == .return) ? "" : string
        // isLimited 语义：只有当“达到限制(==limit)”时才 true；未设置 limit 恒 false
        func limitedFlag(_ text: String) -> Bool {
            guard let limit else { return false };return text.count >= limit
        }
        // 1) 彻底禁用“空格按键”输入（空格不会进入文本）
        if mode == .space {
            onInput?(char, old, .space, limitedFlag(old))
            _ = originalTextFieldDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)
            return false
        }
        // 2) 限制长度：超限直接拦截
        if let limit, new.count > limit {
            onInput?(char, old, mode, limitedFlag(old))
            _ = originalTextFieldDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)
            return false
        }
        // 3) 允许输入：回调 new
        onInput?(char, new, mode, limitedFlag(new))
        // 4) 转发原 delegate 结果
        let originalAllow = originalTextFieldDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
        return originalAllow
    }
    // MARK: - UITextViewDelegate
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        let allow = originalTextViewDelegate?.textViewShouldBeginEditing?(textView) ?? true
        return allow
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        onBegin?(textView.text ?? "")
        originalTextViewDelegate?.textViewDidBeginEditing?(textView)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        onEnd?(textView.text ?? "")
        originalTextViewDelegate?.textViewDidEndEditing?(textView)
    }

    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {
        let old = textView.text ?? ""
        let new = (old as NSString).replacingCharacters(in: range, with: text)
        let mode: JobsTextInputMode = {
            if text == " " { return .space }
            if text == "\n" { return .return }
            if text.isEmpty, range.length > 0 { return .delete };return .normal
        }()
        if let limit, new.count > limit {
            // 变更被拦截：看当前真实文本 old 是否已达到 limit
            let isLimited = (old.count >= limit) // 你要“达到限制才 true”
            let char = (mode == .delete || mode == .return) ? "" : text
            onInput?(char, old, mode, isLimited)
            _ = originalTextViewDelegate?.textView?(textView,
                                                    shouldChangeTextIn: range,
                                                    replacementText: text)
            return false
        }
        // 允许变更：看 new 是否已达到 limit
        let isLimited = (limit != nil) ? (new.count >= (limit ?? Int.max)) : false
        let char = (mode == .delete || mode == .return) ? "" : text
        onInput?(char, new, mode, isLimited)
        let originalAllow = originalTextViewDelegate?.textView?(textView,
                                                                shouldChangeTextIn: range,
                                                                replacementText: text) ?? true
        return originalAllow
    }
}
// MARK: - Associated Keys
private enum JobsTextInputAssociatedKeys {
    static var observer: UInt8 = 0
}
// MARK: - 内部：获取/绑定 observer
public protocol JobsTextInputAttachable: AnyObject {}
extension UITextField: JobsTextInputAttachable {}
extension UITextView: JobsTextInputAttachable {}
extension JobsTextInputAttachable {
    public var jobs_textInputObserver: JobsTextInputObserver {
        if let obj = objc_getAssociatedObject(
            self,
            &JobsTextInputAssociatedKeys.observer
        ) as? JobsTextInputObserver {
            return obj
        }
        let obj = JobsTextInputObserver()
        objc_setAssociatedObject(
            self,
            &JobsTextInputAssociatedKeys.observer,
            obj,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return obj
    }
}

public final class WeakBox<T: AnyObject> {
    public weak var value: T?
    public init(_ value: T?) { self.value = value }
}
