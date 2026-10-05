//
//  JobsDebugPanelResource.swift
//  JobsDebugPanel
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import UIKit
import JobsByUIKit

enum JobsDebugPanelResource {
    static let buttonImage: UIImage? = {
        let frameworkBundle = Bundle(for: JobsDebugButtonVC.self)
        let candidates = [frameworkBundle, Bundle.main]
        for candidate in candidates {
            guard let url = candidate.url(forResource: "JobsDebugPanelResources", withExtension: "bundle"),
                  let bundle = Bundle(url: url),
                  let image = UIImage.make(named: "JobsDebugPanelButton", in: bundle) else {
                continue
            }
            return image
        }
        return nil
    }()
}
#endif
