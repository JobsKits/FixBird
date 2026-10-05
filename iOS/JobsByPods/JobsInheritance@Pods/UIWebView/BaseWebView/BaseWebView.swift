//
//  BaseWebView.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit
import JobsNavBar
import JobsByUIKit
import JobsSwiftDSL
import JobsByWebKit
import JobsSwiftBlock
import JobsSwiftBaseDefines
import SnapKit

/**
 在 Info.plist 添加👇（更通用的 ATS 配置，避免为某域名单独开洞）
     <key>NSAppTransportSecurity</key>
     <dict>
       <!-- 仅放开 Web 内容，其他网络请求仍受 ATS 约束 -->
       <key>NSAllowsArbitraryLoadsInWebContent</key><true/>
     </dict>
 */
public final class BaseWebView: UIView {
    // MARK: - 基础配置项（完全通用，无业务常量）
    public var openBlankInPlace: Bool = true
    public var disableSelectionAndCallout: Bool = false
    public var injectDarkStylePatch: Bool = false
    public var isInspectableEnabled: Bool = true
    /// URL 重写器：返回新的 URL 表示重写；返回 nil 表示不重写（默认 nil）
    public var urlRewriter: ((URL) -> URL?)?
    /// Safari 兜底规则：返回 true 时交给 Safari 打开（默认 nil）
    public var safariFallbackRule: ((URL) -> Bool)?
    /// 循环重写保护
    public var rewriteBurstWindow: TimeInterval = 3
    public var rewriteBurstLimit: Int = 3
    public var allowedHosts: Set<String> = []                         // 空 = 不限制
    public var externalSchemes: Set<String> = [
        "tel",
        "mailto",
        "sms",
        "facetime",
        "itms-apps",
        "maps",
        "weixin",
        "alipays",
        "alipay",
        "mqqapi",
        "line"
    ]
    // MARK: - WKWebViewConfiguration 外部覆盖（外部优先；外部未设置则用内部默认）
    /// 外部覆盖：nil 表示未设置（将使用内部默认值）
    var overrideWebsiteDataStore: WKWebsiteDataStore? = nil
    /// 外部注入：在 WKWebView 初始化前回调，可配置除 dataStore 以外的其它项（或最终覆盖）
    var webViewConfigurationHook: (jobsByWKWebConfigBlock)? = nil
    // MARK: - Fixed no-cache policy
    static let noCacheHeader = "X-Jobs-NoCache"
    let alwaysFreshMainDocument = true
    // MARK: - Bridge
    public typealias NativeBlock = (_ payload: Any?, _ completion: @escaping (Any?) -> Void) -> Void
    public private(set) lazy var progressView: UIProgressView = { [unowned self] in
        UIProgressView(progressViewStyle: .default)
            .byAddTo(self) { make in
                make.top.leading.trailing.equalToSuperview()
            }
    }()

    let bridgeName = "bridge"
    let consoleName = "console"
    let mobileBridgeName = "iOSBridge"

    var handlers: [String: NativeBlock] = [:]

    // Mobile bridge
    var mobileActionHandlers: [String: MobileActionBlock] = [:]
    var mobileConfig: MobileBridgeConfig = .defaults()

    // MARK: - Presenter

    public weak var presenter: UIViewController?

    var presentingVC: UIViewController? {
        presenter ?? nearestViewController() ?? UIApplication.jobsTopMostVC()
    }

    // MARK: - UserAgent

    var uaSuffixProvider: ((URLRequest) -> String?)?
    var lastAppliedUASuffix: String?

    // MARK: - Rewrite state

    var rewriteCount = 0
    var lastRewriteAt = Date.distantPast

    // MARK: - KVO

    private var kvoEstimatedProgress: NSKeyValueObservation?
    private var kvoTitle: NSKeyValueObservation?

    // MARK: - UI

    lazy var configuration: WKWebViewConfiguration = {
        WKWebViewConfiguration()
            // 内部默认：非持久数据仓库（每个 BaseWebView 实例都是全新 session，零共享 Cookie/缓存）
            .byWebsiteDataStore(overrideWebsiteDataStore ?? .nonPersistent())
            .byAllowsInlineMediaPlayback(YES)
            .byWebsiteDataStore(overrideWebsiteDataStore)
            .byUserContentController(
                WKUserContentController().byAddUserScript(Self.makeBridgeUserScript())
            )
    }()
    /// 注意：必须用 configuration init，在 WKWebView 创建前注入 config。
    lazy var webView: WKWebView = { [unowned self] in
        WKWebView(frame: .zero, configuration: configuration)
            .byNavigationDelegate(self)
            .byUIDelegate(self)
            .byInspectable(true)
            .byCustomUserAgent(nil)
            .byConfiguration({ configuration in
                configuration.byApplicationNameForUserAgent(nil)
            })
            .byScrollView({ scrollView in
                scrollView.byAlwaysBounceVertical(true)
                    .byRefreshControl(refresher)
            })
            .byAddTo(self) { [unowned self] make in
                make.top.equalTo(self.progressView.snp.bottom)
                make.leading.trailing.bottom.equalToSuperview()
            }
    }()

    lazy var refresher: UIRefreshControl = {
        UIRefreshControl.jobsMake { _ in }
            .onJobsChange { [weak self] (_: UIRefreshControl) in
                guard let self else { return }
                self.handlePullToRefresh()
            }
    }()
    /// 强引用 DocumentPicker 代理，避免立刻释放
    var docPickerDelegate: DocumentPickerDelegateProxy?
    // MARK: - Init
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @MainActor
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    /// ✅ 推荐构造：在 WKWebView 创建前注入 configuration（确保 websiteDataStore 等初始化参数生效）
    @MainActor
    public convenience init(_ configuration: @escaping jobsByWKWebConfigBlock) {
        self.init(frame: .zero, configuration: configuration)
    }
    /// 带 frame 的注入构造
    @MainActor
    public init(frame: CGRect = .zero, configuration: jobsByWKWebConfigBlock? = nil) {
        super.init(frame: frame)
        webViewConfigurationHook = configuration
        commonInit()
    }

    @MainActor
    private func commonInit() {
        // 先唤起 UI 懒加载（UI/约束都在 lazy block 内）
        progressView.byVisible(true)
        webView.byVisible(true)
        registerMessageHandlers()
        self.byBackgroundColor(JobsCor.clear)
        // 仅做“使用阶段”的配置；UI 生成与约束在 lazy block（progressView/webView）里完成
        progressView.byVisible(true)
        webView.byVisible(true)
        lastAppliedUASuffix = nil
        setupKVO()
        applyRuntimeToggles()
        // 默认启用通用 MobileBridge（零配置可用）
        _ = useMobileBridge()
    }

    deinit {
        cleanupNow()
    }

    private func cleanupNow() {
        kvoEstimatedProgress?.invalidate()
        kvoEstimatedProgress = nil
        kvoTitle?.invalidate()
        kvoTitle = nil
        webView.stopLoading()
        webView
            .byNavigationDelegate(nil)
            .byUIDelegate(nil)
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.removeScriptMessageHandler(forName: bridgeName)
        ucc.removeScriptMessageHandler(forName: consoleName)
        ucc.removeScriptMessageHandler(forName: mobileBridgeName)
        handlers.removeAll()
        mobileActionHandlers.removeAll()
        docPickerDelegate = nil
    }
}
// MARK: - Internal assemble
private extension BaseWebView {
    @MainActor
    func registerMessageHandlers() {
        let ucc = webView.configuration.userContentController
        if #available(iOS 14.0, *) {
            let weakH = WeakScriptMessageHandlerWithReply(target: self)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: bridgeName)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: consoleName)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: mobileBridgeName)
        } else {
            ucc.add(WeakScriptMessageHandler(target: self), name: bridgeName)
            ucc.add(WeakScriptMessageHandler(target: self), name: consoleName)
            ucc.add(WeakScriptMessageHandler(target: self), name: mobileBridgeName)
        }
    }

    @MainActor
    func setupKVO() {
        kvoEstimatedProgress = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            guard let p = change.newValue else { return }
            onMainAsync { [weak self] in
                guard let self else { return }
                self.progressView.byHidden(p >= 1.0)
                self.progressView.setProgress(Float(p), animated: true)
                if p >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        guard let self else { return }
                        self.progressView.byProgress(0)
                    }
                }
            }
        }
        kvoTitle = webView.observe(\.title, options: [.new]) { _, _ in }
    }

    @MainActor
    func applyRuntimeToggles() {
        injectDarkCSSIfNeeded()
        setSelectionDisabled(disableSelectionAndCallout)
    }
}
// MARK: - Public API
public extension BaseWebView {
    @discardableResult
    @MainActor
    func loadBy(_ url: URL) -> Self {
        if url.isFileURL {
            let readAccess = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: readAccess)
        } else {
            let req = URLRequest(url: url)
            webView.load(makeNoCache(req))
        };return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ urlString: String) -> Self {
        if let url = URL(string: urlString) {
            let req = URLRequest(url: url)
            webView.load(makeNoCache(req))
        };return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ url: URL,
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                timeout: TimeInterval = 60) -> Self {
        // ⚠️ 对外签名保留，但内部一律走无缓存策略（忽略传入的 cachePolicy）
        var req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
        req = makeNoCache(req)
        webView.load(req)
        return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ request: URLRequest) -> Self {
        webView.load(makeNoCache(request))
        return self
    }

    @discardableResult
    @MainActor
    func loadHTMLBy(_ html: String, baseURL: URL? = nil) -> Self {
        webView.loadHTMLString(html, baseURL: baseURL)
        return self
    }
    /// 加载 App Bundle 内的本地 HTML 文件（链式）
    @discardableResult
    @MainActor
    func loadBundleHTMLBy(named name: String,
                          in subdirectory: String? = nil,
                          bundle: Bundle = .main) -> Self {
        if let url = bundle.url(forResource: name, withExtension: "html", subdirectory: subdirectory) {
            return loadBy(url)
        }
        if let urls = bundle.urls(forResourcesWithExtension: "html", subdirectory: nil),
           let url = urls.first(where: { $0.lastPathComponent == "\(name).html" }) {
            return loadBy(url)
        }
        assertionFailure("HTML '\(name).html' not found in bundle")
        return self
    }

    func on(_ name: String, handler: @escaping NativeBlock) { handlers[name] = handler }
    func off(_ name: String) { handlers.removeValue(forKey: name) }

    @MainActor
    func emitEvent(_ name: String, payload: Any?) {
        let js = "window.Native && window.Native.emit(\(Self.quote(name)), \(Self.toJSONLiteral(payload)));"
        webView.jobsEval(js)
    }

    @MainActor
    func callJS(function: String,
                args: [Any] = [],
                completion: JobsByAnyErrMASendableBlock? = nil) {
        let jsArgs = args.map(Self.toJSONLiteral).joined(separator: ",")
        webView.jobsEval("\(function)(\(jsArgs));", completion: completion)
    }
}
// MARK: - JS eval（Raw + Decodable）
public extension BaseWebView {
    @available(iOS 13.0, *)
    func evalAsyncRaw(_ js: String, timeout: TimeInterval = 8) async throws -> Any? {
        try await withThrowingTaskGroup(of: Any?.self) { group in
            group.addTask { [weak webView] in
                guard let webView else {
                    throw NSError(domain: "BaseWebView", code: -10, userInfo: [NSLocalizedDescriptionKey: "deallocated"])
                }
                if #available(iOS 15.0, *) {
                    return try await webView.evaluateJavaScript(js)
                } else {
                    return try await withCheckedThrowingContinuation { cont in
                        onMainAsync {
                            webView.jobsEval(js) { res, err in
                                if let err {
                                    cont.resume(throwing: err)
                                } else {
                                    cont.resume(returning: res)
                                }
                            }
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1e9))
                throw NSError(domain: "BaseWebView", code: -1, userInfo: [NSLocalizedDescriptionKey: "JS eval timeout"])
            }
            let v = try await group.next()!!
            group.cancelAll()
            return v
        }
    }

    @available(iOS 13.0, *)
    func evalAsync<T: Decodable>(_ js: String,
                                 as type: T.Type = T.self,
                                 timeout: TimeInterval = 8,
                                 decoder: JSONDecoder = JSONDecoder.make { _ in }) async throws -> T {
        let raw = try await evalAsyncRaw(js, timeout: timeout)
        return try Self.decodeJSResult(raw, as: T.self, decoder: decoder)
    }
}
// MARK: - Cookies / Selection
public extension BaseWebView {
    @MainActor
    func setCookies(_ cookies: [HTTPCookie], completion: (jobsByVoidBlock)? = nil) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        cookies.forEach { c in
            group.enter()
            store.setCookie(c) { group.leave() }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }

    @MainActor
    func setSelectionDisabled(_ disabled: Bool) {
        disableSelectionAndCallout = disabled
        let js = """
        (function(){
          var el = document.documentElement;
          el.style.webkitUserSelect=\(disabled ? "'none'" : "''");
          el.style.webkitTouchCallout=\(disabled ? "'none'" : "''");
        })();
        """
        webView.jobsEval(js)
    }
}
// MARK: - MobileBridge API
public extension BaseWebView {
    @discardableResult
    @MainActor
    func useMobileBridge(_ cfg: MobileBridgeConfig = .defaults()) -> Self {
        mobileConfig = cfg
        injectMinimalMobileShimIfNeeded()
        return self
    }

    @discardableResult
    func registerMobileAction(_ name: String, _ handler: @escaping MobileActionBlock) -> Self {
        mobileActionHandlers[name] = handler
        return self
    }

    @discardableResult
    func unregisterMobileAction(_ name: String) -> Self {
        mobileActionHandlers.removeValue(forKey: name)
        return self
    }
}
