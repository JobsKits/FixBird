//
//  JobsSplashPresenter.swift
//  JobsSwiftSplash
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL

public enum JobsSplashPresenter {
    @discardableResult
    @MainActor
    public static func show(
        over hostViewController: UIViewController,
        configuration: JobsSplashConfiguration
    ) -> JobsSplashVC {
        let hostGestureStates = (hostViewController.view.gestureRecognizers ?? []).map {
            (gestureRecognizer: $0, isEnabled: $0.isEnabled)
        }
        hostGestureStates.forEach {
            $0.gestureRecognizer.byEnabled(false)
        }
        let splashVC = JobsSplashVC(configuration: configuration)
            .byFrame(hostViewController.view.bounds)
        splashVC.restoreHostGesturesOnFinish {
            hostGestureStates.forEach {
                $0.gestureRecognizer.byEnabled($0.isEnabled)
            }
        }
        hostViewController.addChild(splashVC)
        splashVC.view
            .byAutoresizingMask([.flexibleWidth, .flexibleHeight])
            .byAddTo(hostViewController.view)
        splashVC.didMove(toParent: hostViewController)
        DispatchQueue.main.async { [weak splashVC] in
            splashVC?.becomeFirstResponder()
        };return splashVC
    }
}
