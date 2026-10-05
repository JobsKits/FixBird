//
//  JobsDebugAction.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit

public final class JobsDebugAction {
    public private(set) var title = ""
    public private(set) var image: UIImage?
    public private(set) var action: ((UIViewController) -> Void)?

    public init() {}

    @discardableResult
    public func byTitle(_ title: String) -> Self {
        self.title = title
        return self
    }

    @discardableResult
    public func byImage(_ image: UIImage?) -> Self {
        self.image = image
        return self
    }

    @discardableResult
    public func byAction(_ action: @escaping (UIViewController) -> Void) -> Self {
        self.action = action
        return self
    }
}
#endif
