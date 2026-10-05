//
//  UIImage+Make.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit

extension UIImage {
    /// 私有 API 返回的图片在内存解码，不暴露下载地址。
    static func make(data: Data) -> UIImage? {
        return UIImage(data: data)
    }

    /// 本地 Pod 的压缩实现不是 public，宿主在此收口有界缩图与 JPEG 编码。
    func marketplaceQualificationJPEG(maxBytes: Int) -> Data? {
        guard maxBytes > 0, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else {
            return nil
        }
        let originalLongest = max(size.width, size.height)
        var longest = min(originalLongest, 2048)
        for _ in 0..<5 {
            let ratio = longest / originalLongest
            let target = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: target, format: format).image { context in
                let rect = CGRect(origin: .zero, size: target)
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(rect)
                self.draw(in: rect)
            }
            for quality in [CGFloat(0.85), 0.65, 0.45, 0.25] {
                if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                    return data
                }
            }
            longest *= 0.75
        }
        return nil
    }
}
