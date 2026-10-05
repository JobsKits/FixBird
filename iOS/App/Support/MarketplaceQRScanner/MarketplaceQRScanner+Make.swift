//
//  MarketplaceQRScanner+Make.swift
//  RepairMarketplace
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit
import AVFoundation
import JobsSwiftDSL
import JobsByUIKit

/// 捕获图和相机权限封装在宿主组件内，业务页只接收二维码文本。
final class MarketplaceQRScanner: UIView, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession.jobsMake { _ in }
    private let queue = DispatchQueue(label: "com.jobs.repairmarketplace.qr-camera")
    private var preview: AVCaptureVideoPreviewLayer?
    private var configured = false
    private var shouldRun = false
    private var delivered = false
    private var onScanned: ((String) -> Void)?
    private var onFailure: ((String) -> Void)?

    static func make() -> MarketplaceQRScanner {
        return MarketplaceQRScanner(frame: .zero)
    }

    @discardableResult
    func byScanned(_ action: @escaping (String) -> Void) -> Self {
        onScanned = action
        return self
    }

    @discardableResult
    func byFailure(_ action: @escaping (String) -> Void) -> Self {
        onFailure = action
        return self
    }

    @discardableResult
    func byStart() -> Self {
        delivered = false
        queue.async { [weak self] in
            self?.shouldRun = true
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        /// 已授权后才启动捕获。
        case .authorized:
            startAuthorized()
        /// 用户点击扫码入口时才申请权限。
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.delivered == false else {
                        return
                    }
                    if granted {
                        self.startAuthorized()
                    } else {
                        self.onFailure?("相机权限未授权，可粘贴二维码内容。")
                    }
                }
            }
        /// 拒绝或受系统限制时保留粘贴入口。
        default:
            onFailure?("相机权限未授权，可粘贴二维码内容。")
        }
        return self
    }

    @discardableResult
    func byStop() -> Self {
        delivered = true
        queue.async { [weak self] in
            guard let self else {
                return
            }
            self.shouldRun = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        return self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview?.byFrame(bounds)
    }

    deinit {
        let session = session
        queue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func startAuthorized() {
        queue.async { [weak self] in
            guard let self, self.shouldRun else {
                return
            }
            do {
                try self.configureCapture()
                if self.session.isRunning == false {
                    self.session.startRunning()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.delivered == false else {
                        return
                    }
                    self.onFailure?("当前设备无法使用相机，可粘贴二维码内容。")
                }
            }
        }
    }

    private func configureCapture() throws {
        guard configured == false else {
            return
        }
        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw CocoaError(.featureUnsupported)
        }
        let input = try AVCaptureDeviceInput(device: camera)
        let output = AVCaptureMetadataOutput.jobsMake { _ in }
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CocoaError(.featureUnsupported)
        }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        configured = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let preview = AVCaptureVideoPreviewLayer(session: self.session)
            preview.videoGravity = .resizeAspectFill
            self.preview = preview
            self.layer.byAddSublayer(preview)
            self.bySetNeedsLayout()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard delivered == false, let value = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else {
            return
        }
        byStop()
        onScanned?(value)
    }
}
