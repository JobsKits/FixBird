# `JobsSwiftBlock`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

---

## 🔥 <font id=前言>前言</font>

`JobsSwiftBlock` 集中提供 <u>[**Swift**](https://www.swift.org/)</u> Block / closure 类型别名，并承接不能放在高层 UI Pod 的最低层创建 closure。

## 一、创建与依赖边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `NSObject.jobsMake { object in ... }` 统一无参系统对象创建，原生 `init()` 只存在于该入口内部。
- `NSObject` 统一遵循 `JobsNSObjectMaking`，工厂在 `Self: NSObject` 的协议扩展中实现；配置参数和返回值都保留调用类型，调用方无需额外遵循协议或改变现有写法。
- `JSONDecoder.make { decoder in ... }` / `JSONEncoder.make { encoder in ... }` 为不继承 `NSObject` 的 [**Foundation**](https://developer.apple.com/documentation/foundation/timer) 类提供同语义入口。
- `JobsSwiftDSL` 通过桥接文件公开转出本 Pod；底层 Pod 可以直接依赖 `JobsSwiftBlock`，避免为了创建对象反向依赖 `JobsByUIKit`。

创建完成后的属性、无参实例方法和单参实例方法不由本 Pod 承担，统一进入真实类型的 `JobsSwiftDSL.byXxx(...)`。

## 二、编译兼容与回归 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 工厂使用协议泛型 `Self`，避免类扩展动态 `Self` 在协议调用方的 IR 生成路径。[**Xcode**](https://developer.apple.com/xcode) 26.3 / <u>[**Swift**](https://www.swift.org/)</u> 6.2.4 曾在 `JobsCallbackable.jobs_callbackStore` 调用工厂时于 `getDynamicSelfMetadata()` 崩溃；不能仅用语法解析通过判断该问题已修复。
- [**GitHub Actions**](https://docs.github.com/en/actions) 工作流 `../../.github/workflows/build_simulator_app.yml` 在安装依赖之前执行 `../../.github/tests/JobsSwiftBlockRegression.swift`，验证跨模块调用、具体子类、动态元类型、配置闭包只执行一次，以及回调注册、替换、移除、返回值和实例隔离。
- 同一检查使用当前 [**Xcode**](https://developer.apple.com/xcode) 为 `arm64`、`x86_64` 模拟器生成实际回调源码的 IR；完整 App 构建仍保持 `ONLY_ACTIVE_ARCH=NO`，不通过排除架构或忽略编译失败放行。
- 完整构建失败时上传 `Simulator-Build-Diagnostics-运行ID-尝试次数`，包含 `simulator-build.log` 和 `SimulatorBuild.xcresult`。日志经过 `tee` 保存，但 `pipefail` 保留真实构建失败状态。

<a id="jobs-architecture"></a>

## 三、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 3.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

提供统一闭包类型、对象回调登记和轻量创建配置入口。JobsCallbackable 以稳定键保存闭包，调用方法按参数与返回类型取出执行；[**JSON**](https://www.json.org/json-en.html) 编解码器和 NSObject 的创建入口复用同一配置思想。

### 3.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

选择闭包类型与键 → 在对象上注册 → 事件发生时按键和签名调用 → 替换或清除绑定

### 3.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 回调容器以 String 到 Any 保存，注册和读取的签名必须对应；键正确但类型不一致仍无法正确调用。
- 以 #function 推导键时有规范化规则，重建不能让注册端和调用端采用不同字符串。
- 闭包可能捕获所属对象，宿主应明确弱引用与清理边界，避免对象和回调互相持有。
- 基础闭包、第三方专用闭包和对象工厂是三类入口，不能把第三方类型依赖隐去后承诺完全独立。

### 3.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 BaseBlock 与 Callbackable，再看键规范化和调用重载，最后看 ThirdPodsBlock 及 Make 扩展。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JSONCoder+Make.swift](<./JSONCoder+Make.swift>)
- [JobsCallbackable.swift](<./JobsCallbackable.swift>)
- [JobsSwift3rdPodsBlock.swift](<./JobsSwift3rdPodsBlock.swift>)
- [JobsSwiftBaseBlock.swift](<./JobsSwiftBaseBlock.swift>)
- [NSObject+Make.swift](<./NSObject+Make.swift>)

依赖与编译入口：[JobsSwiftBlock.podspec](<./JobsSwiftBlock.podspec>)。当前显式依赖声明包括 `SnapKit`、`Kingfisher`、`Moya`。`JobsSwift3rdPodsBlock.swift` 中的 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) 类型别名受 `canImport(YTKNetwork)` 保护；需要旧适配器的宿主工程应自行显式加入 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork)，本 RepairMarketplace 工程统一使用 `JobsNetworking`，不安装旧网络栈。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
