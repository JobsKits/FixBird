# `JobsInheritance`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

---

## 🔥 <font id=前言>前言</font>

> `JobsInheritance` 集中维护 Jobs <u>[**Swift**](https://www.swift.org/)</u> 工程的公共基类。

## 一、控制器基类 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 业务控制器统一继承 `BaseVC`，避免直接继承 `UIViewController` 后重复配置公共行为。
- `BaseVC` 在 `viewWillAppear(_:)` 和 `viewDidAppear(_:)` 调用 `jobsEnsureNavigationDefaults()`，统一兜底 Jobs/GK 导航栏、Jobs 返回按钮和标题，但不覆盖页面在 `viewDidLoad` 中声明的背景色；标题优先沿用跳转入口传入值，根页面不处理，专门演示系统导航栏的 `JobsNavigationDemoVC` 保持原样。
- `BaseVC` 在 `viewDidAppear(_:)` 按导航栈深度恢复系统侧滑返回能力。

## 二、明暗主题契约 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 页面、列表和弹框的普通承载面使用 `JobsCor.systemBackground` / `JobsCor.secondarySystemBackground`，正文、说明和占位文字使用 `JobsCor.label` / `JobsCor.secondaryLabel` / `JobsCor.placeholderText`，确保白天浅底深字、黑夜深底浅字。
- 品牌色、媒体画布、二维码、相机、视频、手写和马赛克内容保留业务色；颜色写入 `CGColor`、`CALayer` 或自绘上下文时，需要在主题 Trait 变化后重新解析和绘制。
- 验证时从 Demo 全局主题入口分别切换白天和黑夜，检查组件的背景、文字、禁用态、占位态与弹出层对比度。

## 三、Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## 四、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 4.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

以继承方式提供常用 [**UIKit**](https://developer.apple.com/documentation/uikit) 组件和页面基类，覆盖按钮式图片视图、带内边距标签、表格 Cell、输入框、基础控制器及网页容器。公共基类承接复用行为，具体子类仍由业务配置。

### 4.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

选择适合的基类 → 配置子视图或页面能力 → 绑定事件与桥接 → 宿主管理展示及销毁

### 4.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- JobsButton 实际继承 UIImageView，并非 UIButton；标题、副标题和前景图属于其自有子视图，不能直接套用 UIButton 的状态模型。
- 前景图片加载期间的 nil 与显式隐藏图片区域是不同语义，重建时不能无条件清空预留布局。
- 网页相关能力拆成配置、桥接、下载及导航栏宿主等文件，需要分别理解消息入口、网页导航和资源生命周期。
- 不要让所有业务页面都强制承担不使用的网页、播放器或表格功能；先重建实际需要的基类边界。

### 4.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先选具体基类阅读，再沿扩展文件看组合关系；网页部分从 BaseWebVC/BaseWebView 追到 Bridge、Download 和 NavBarHost。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [UIWebView/BaseWebView/BaseWebView+Bridge.swift](<./UIWebView/BaseWebView/BaseWebView+Bridge.swift>)
- [UIWebView/BaseWebView/BaseWebView+MobileBridge.swift](<./UIWebView/BaseWebView/BaseWebView+MobileBridge.swift>)
- [UIWebView/BaseWebView/BaseWebView.swift](<./UIWebView/BaseWebView/BaseWebView.swift>)
- [UIViewController/BaseWebVC.swift](<./UIViewController/BaseWebVC.swift>)
- [UITableViewCell/BaseTableViewCellByDefault.swift](<./UITableViewCell/BaseTableViewCellByDefault.swift>)

依赖与编译入口：[JobsInheritance.podspec](<./JobsInheritance.podspec>)。其中显式依赖声明包括 `SnapKit`、`GKNavigationBarSwift`、`JobsToast`、`JobsNavBar`、`JobsByUIKit`、`JobsByWebKit`、`JobsSwiftBlock`、`JobsSwiftDebugTools`、`JobsSwiftFoundation`、`JobsSwiftBaseDefines`、`JobsSwiftStandardLibrary`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
