# `JobsSwiftOpen`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#jobs-toc-heading-1)
- [一、功能说明](#jobs-toc-heading-2)
- [二、接入示例](#jobs-toc-heading-3)
- [三、Jobs DSL 调用约定](#jobs-toc-heading-4)
- [四、架构脉络与关键设计](#jobs-toc-heading-5)
  - [4.1、设计目的与职责划分](#jobs-toc-heading-6)
  - [4.2、运行脉络](#jobs-toc-heading-7)
  - [4.3、关键设计与边界](#jobs-toc-heading-8)
  - [4.4、阅读与重建顺序](#jobs-toc-heading-9)

</details>
<!-- jobs-toc:end -->

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">🔥 <font id=前言>前言</font></span><!-- jobs-toc:heading-end -->

> `JobsSwiftOpen` 是 <u>[**Swift**](https://www.swift.org/)</u> URL 打开组件，统一管理应用内网页和系统默认浏览器两种打开方式。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 默认 URL：`http://www.baidu.com`。
- 默认模式：`.inApp`，使用应用内 `WKWebView` 页面。
- 外部模式：`.externalBrowser`，交给系统默认浏览器。
- 应用内打开时优先压入当前导航栈；没有导航栈时使用全屏导航控制器承载。
- 应用内网页统一显示返回按钮：存在网页浏览历史时优先网页后退，否则退出当前 [**Web**](https://developer.mozilla.org/en-US/docs/Web) 页面；同时支持导航栈和模态导航容器。
- 应用内网页的视图约束统一使用 `SnapKit`。

依赖：`SnapKit`、`JobsInheritance`、`JobsByUIKit`、`GKNavigationBarSwift`。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、接入示例 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```swift
import JobsSwiftOpen

JobsOpen.shared.open(
    JobsOpenConfiguration()
        .byURL(URL(string: "https://www.baidu.com")!)
        .byMode(.inApp),
    from: self
)
```

将 `mode` 设为 `.externalBrowser` 时，改用系统默认浏览器打开。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### <span id="jobs-toc-heading-6" data-jobs-toc="v2">4.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

用 JobsOpenConfiguration 收集 URL、打开模式、标题和完成回调，JobsOpen 分流到应用内网页控制器或系统默认浏览器；网页控制器管理加载及返回。

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">4.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

构造 URL 与模式 → 应用内展示或转交系统 → 回报打开动作 → 网页容器继续处理加载与返回

### <span id="jobs-toc-heading-8" data-jobs-toc="v2">4.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 当前 <u>[**Swift**](https://www.swift.org/)</u> 入口围绕 URL 的应用内与外部浏览器分流，不能直接套用 OC 侧所有拨号、邮件便利分类。
- 打开动作完成不等于网页内容加载完成，这两个阶段需要分别处理。
- 应用内返回行为需区分网页历史和关闭控制器，不能无条件只做 pop。
- 宿主需要提供可用展示控制器或导航环境，不能假定全局窗口一定适合展示。

### <span id="jobs-toc-heading-9" data-jobs-toc="v2">4.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

先读 Configuration 和 JobsOpen 的分支，再看 JobsOpenWebViewController 的加载与 handleBack。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Core/JobsOpenWebViewController.swift](<./Core/JobsOpenWebViewController.swift>)
- [Core/JobsOpen.swift](<./Core/JobsOpen.swift>)
- [Core/JobsOpenConfiguration.swift](<./Core/JobsOpenConfiguration.swift>)

依赖与编译入口：[JobsSwiftOpen.podspec](<./JobsSwiftOpen.podspec>)。其中显式依赖声明包括 `SnapKit`、`JobsInheritance`、`JobsByUIKit`、`GKNavigationBarSwift`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
