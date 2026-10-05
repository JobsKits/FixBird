# `JobsSwiftDSL`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

---

## 🔥 <font id=前言>前言</font>

`JobsSwiftDSL` 用于集中管理 <u>[**Swift**](https://www.swift.org/)</u> 工程里的点语法 / 链式语法糖，例如 `byTitle(...)`、`byFrame(...)`、`dsl { ... }`。

## 一、适用场景 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 从 `JobsByPods` 内各个本地管理 Pod 抽出的系统 SDK / 第三方 SDK 二次封装。
- Jobs 自维护的 <u>[**Swift**](https://www.swift.org/)</u> 主工程和本地 Pods 显式 `import JobsSwiftDSL` 后使用点语法，不在调用方回退到已有 DSL 覆盖的系统 API。
- `JobsCor` 语义背景色、文字色经 `byBackgroundColor(...)`、`byTextColor(...)`、`byTitleColor(...)` 等 DSL 自动登记到 `JobsThemeCenter`；也可使用 `byThemeBackground(...)`、`byThemeTextColor(...)` 和 `byThemeImage(...)` 显式绑定主题 Key。
- `UIButton.byClearConfigurationBackground()` 会持续清除普通、选中、高亮等状态下的配置背景，并在旧系统同步移除背景图，适合只保留前景图标 / 文字的导航按钮。
- `UIView.byAccessibilityLabel(_:) -> Self` 在真实 UIView 层配置无障碍文案，按钮等子类保持原返回类型继续链；[`JobsDebugPanel`](../JobsDebugPanel@Pods/README.md) 的圆按钮使用它说明点按与长按行为。
- 发现封装缺口时先在本 Pod 的正确类型层补齐，再同步业务代码与 [**Xcode**](https://developer.apple.com/xcode) CodeSnippets。

## 二、目录结构 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 目录 | 内容 |
| ---- | ---- |
| `UIKit/` | `UIView`、`UIButton`、`UILabel`、`UITableView` 等 [**UIKit**](https://developer.apple.com/documentation/uikit) DSL |
| `QuartzCore/` | `CALayer`、`CAAnimation`、`CATransform3D` 等链式封装 |
| `WebKit/` | `WKWebView`、`WKWebViewConfiguration` 等链式封装 |
| `PDFKit/` | `PDFView`、`PDFThumbnailView` 链式封装 |
| `PhotosUI/` | `PHPickerConfiguration`、`PHPickerViewController` 链式封装 |
| `MetalKit/` | `MTKView`、`MTL*Descriptor` 链式封装 |
| `Foundation/` | `JSONDecoder`、`NSMutableAttributedString` 等 [**Foundation**](https://developer.apple.com/documentation/foundation/timer) DSL |
| `CoreMotion/` | `CMMotionManager` 的传感器频率、启停、队列回调与参考坐标系 DSL |
| `ThirdParty/` | `SnapKit`、`BMPlayer`、`YTKNetwork`、`GKNavigationBarSwift` 等第三方 DSL；[**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) 扩展仅在宿主工程同时显式提供 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) / [**AFNetworking**](https://github.com/AFNetworking/AFNetworking) 时参与编译 |

## 三、引用方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```swift
import JobsSwiftBaseDefines
import JobsSwiftDSL

let label = UILabel.jobsMake { label in
  label
    .byText("Jobs")
    .byThemeTextColor(.textPrimary)
    .byTextAlignment(.center)
    .byLabelShadowColor(.black)
    .byLabelShadowOffset(CGSize(width: 0, height: 1))
    .byTintColor(JobsCor.systemBlue)
}

func togglePassword(_ textField: UITextField) {
  textField.byToggleSecureTextEntry()
}

func configure(button: UIButton) {
  button
    .bySelected(false)
    .byToggleSelected()
    .bySemanticContentAttribute(.unspecified)
    .byTitleAdjustsFontSizeToFitWidth(true)
    .byTitleMinimumScaleFactor(0.72)
}

func configure(path: UIBezierPath) {
  path
    .byMove(to: .zero)
    .byAddLine(to: CGPoint(x: 20, y: 20))
    .byClose()
}

func show(view: UIView) {
  UIView.jobsAnimateWithOptions(
    0.25,
    options: [.curveEaseOut],
    animations: { view.byAlpha(1) }
  )
}

let motionManager = CMMotionManager.make()
    .byGyroUpdateInterval(1.0 / 30.0)
    .byStartGyroUpdates(to: .main) { data, error in
        print(data?.rotationRate as Any, error as Any)
    }
```

## 四、风险说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 本 Pod 是语法糖层，不应该承载业务状态。
- `CMMotionManager.byStopAllUpdates()` 只负责统一停止当前 manager 的四类更新；页面仍需持有 manager，并在离开或销毁时主动调用。
- 后续新增 DSL 时，优先放在这里，不再散落到各个功能 Pod。
- `UIView.tintColor` 这类父类公共属性只在 `UIView` DSL 中封装，子类不重复声明同名 API。
- `UILabel.byLabelShadowColor` / `byLabelShadowOffset` 配置文字阴影；`UIView.byShadowColor` / `byShadowOffset` 配置 CALayer 阴影，两套语义不得混用。
- 不带约束的视图装配统一使用 `UIView.byAddTo(_:)`；带 [**SnapKit**](https://github.com/SnapKit/SnapKit) 约束的重载由 `JobsByUIKit` 承接。
- <u>[**Swift**](https://www.swift.org/)</u> 侧布局统一使用 `SnapKit`；本 Pod 不提供创建或激活系统 `NSLayoutConstraint` 的桥接入口。
- `UIView` 动画 overload 由 `jobsAnimate...` / `jobsAnimateKeyframes(...)` / `jobsAddKeyframe(...)` / `jobsPerformWithoutAnimation(...)` / `jobsTransition(...)` / `jobsTransitionFromViewToView(...)` 类级终止动作屏蔽；`UIBezierPath` 实例编排使用 `byMove` / `byAddLine` / `byAddArc` / `byAppend` / `byClose` / `byFill`。
- `UIButton.jobsResetBtnImage` / `jobsResetBtnBgImage` 在 [**iOS**](https://developer.apple.com/ios/) 15+ 同步 `UIButton.Configuration` 后只请求下一帧刷新，不在异步图片回调中强制布局。
- `UIButton.byContentInsets` / `byContentEdgeInsets` 把 [**iOS**](https://developer.apple.com/ios/) 15+ `UIButton.Configuration.contentInsets` 与旧系统 `contentEdgeInsets` 回退收口到封装内部，上层不写版本分支，也不承接系统 deprecated 标记。
- `UIWindow.byScreen`、`WKWebViewConfiguration.byProcessPool` / `bySelectionGranularity` 同样不复制系统 deprecated 标记；scene 映射、旧系统赋值和新系统无效语义均由封装内部按版本处理。
- RGB、灰度和 HSB 颜色分别使用 `UIColor(r:g:b:a:)`、`UIColor(gray:alpha:)`、`UIColor(h:s:b:a:)`。
- `UITextField.byPlaceholder(_:)` 由本 Pod 唯一承接；`JobsByUIKit` 只补充占位颜色、字体等增强能力，不重复声明基础文字 API。
- 封装实现内部可以调用系统 API；上层调用方必须使用对应 `byXxx` / `onXxx` 入口。
- 原 Pod 暂时保留薄桥接文件，便于老代码平滑迁移。

## 五、Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

- `NSObject` 子类的无参创建使用 `Type.jobsMake { object in ... }`；通用创建 Block 的底层实现位于 `JobsSwiftBlock`，由本 Pod 公开转出。
- 带参系统初始化由真实类型提供 `make(arguments, configure:)`，例如 `NSUserActivity.make(activityType:configure:)`；系统构造器只留在工厂实现内。
- 实例创建后，属性、无参实例方法和单参实例方法统一使用返回 `Self` 的 `byXxx(...)`；查询与明确终止动作除外。

`UITableViewCell` 的标题、副标题、图片、`contentView` 与选择状态都从 `cell` 继续点出，不重新起 `cell.textLabel` / `cell.detailTextLabel` / `cell.imageView`：

```swift
return cell
    .byText("关闭".tr)
    .byTitleCor(JobsCor.systemBlue)
    .byTitleTextAlignment(.center)
    .byTitleFont(JobsFont.systemFont(ofSize: 16, weight: .semibold))
    .byDetailText(nil)
    .bySelectionStyle(.default)
    .byContentView { $0.byBackgroundColor(JobsCor.systemBackground) }
```

- `UITableViewCell` 子对象闭包：`byTextLabel`、`byDetailTextLabel`、`byImageView`、`byContentView`。
- `UITableViewCell` 文本收口：`byTitleTextAlignment`、`byTitleNumberOfLines`、`byDetailTitleTextAlignment`、`byDetailTitleNumberOfLines`。
- `UIDatePicker` / `UIPickerView` 的模式、日期范围、代理和数据源配置统一由本 Pod 承接；需要兼容旧系统的滚轮样式使用 `byWheelsStyleIfAvailable()` 保持主链不断开，`JobsByUIKit` 通过公开桥接继续兼容原 import。

<a id="jobs-architecture"></a>

## 六、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 6.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

作为系统对象链式配置的集中层，按 [**Foundation**](https://developer.apple.com/documentation/foundation/timer)、[**UIKit**](https://developer.apple.com/documentation/uikit)、[**QuartzCore**](https://developer.apple.com/documentation/quartzcore/cadisplaylink)、WebKit、PDFKit、PhotosUI、MetalKit 等框架划分扩展，统一 byXxx 与配置闭包表达，承接原先散落在多个 Pod 的 DSL。

### 6.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

创建目标对象 → 链式配置属性或子对象 → 执行明确的行为入口 → 返回当前对象继续配置

### 6.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 链式返回尽量保持 Self，不能在中途降为父类后丢失子类接口；值类型需要按复制返回规则处理。
- 配置和 start/stop 等明确行为入口要区分，不能把有副作用的方法理解成普通属性设置。
- 兼容 Pod 的桥接与本层实现要保持单一归属，防止重复扩展引发歧义。
- 系统版本差异在相应扩展内部消化，例如日期选择器的可用样式；无条件调用新 API 会破坏旧系统支持。

### 6.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先按目标框架找到扩展，再检查接收类型、返回类型和版本条件，最后沿 JobsByUIKit 等使用方看完整链条。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsSwiftBlockBridge.swift](<./JobsSwiftBlockBridge.swift>)
- [UIKit/iOS.SDK/UIView/UIView+DSL.swift](<./UIKit/iOS.SDK/UIView/UIView+DSL.swift>)
- [Foundation/JSONDecoder.swift](<./Foundation/JSONDecoder.swift>)
- [MetalKit/MTKView.swift](<./MetalKit/MTKView.swift>)
- [PDFKit/PDFThumbnailView.swift](<./PDFKit/PDFThumbnailView.swift>)

依赖与编译入口：[JobsSwiftDSL.podspec](<./JobsSwiftDSL.podspec>)。当前显式依赖声明包括 `JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsTextTools`、`RxSwift`、`RxCocoa`、`SnapKit`、`BMPlayer`、`GKNavigationBarSwift`。[**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) 扩展源码仍由 `canImport` 保护，但本工程不声明 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) / [**AFNetworking**](https://github.com/AFNetworking/AFNetworking) 依赖；业务网络请求统一使用 Jobs `JobsNetworking`。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
