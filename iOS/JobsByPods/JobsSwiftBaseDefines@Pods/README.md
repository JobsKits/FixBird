# <font id=前言>`JobsSwiftBaseDefines@Pods`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---
> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

JobsFont 提供系统字体静态工厂的 Jobs 等价入口；上层代码使用 JobsFont.systemFont(...)、JobsFont.boldSystemFont(...)、JobsFont.monospacedDigitSystemFont(...) 和 JobsFont.preferredFont(...)，底层统一承接 [**UIKit**](https://developer.apple.com/documentation/uikit)。

JobsCor 提供 [**UIKit**](https://developer.apple.com/documentation/uikit) 基础色、系统色和动态语义色的 Jobs 等价入口；上层代码使用 JobsCor.clear、JobsCor.white、JobsCor.systemBlue 等属性，底层统一承接 UIColor。

`JobsThemeCenter` 提供主题数据包解析、状态持久化、弱引用资源绑定和 `JobsThemeDidChange` 通知。App 在主工程资源目录维护 `JobsThemeResources.json`，框架只消费 `background.*`、`text.*` 等 Key，不包含具体业务色值。切换主题只重放已登记的背景色、文字色以及显式声明的主题图片，不遍历 Scene、Window 或控制器树，也不写入 `overrideUserInterfaceStyle`。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

集中维护基础常量、枚举、协议、结构、颜色字体入口和主题机制，给上层组件提供一致表达。主题系统消费宿主资源中的语义 Key，并通知已登记的 UI 赋值重新应用。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

宿主提供基础配置和主题资源 → 上层使用定义或语义颜色 → 登记可刷新赋值 → 主题变化时重放

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- JobsThemeResources.json 由主工程维护，基础层不应混入具体业务颜色。
- 主题切换只重放已登记的背景、文字及显式声明的主题图片，不遍历全部窗口和控制器，也不设置全局 overrideUserInterfaceStyle。
- Cell 数据协议、默认配置与空实现只是契约起点；返回零高度的默认方法不代表业务布局已经完成。
- 基础回调通过独立 Block 层衔接，复建时避免让定义层反向依赖全部业务 UI。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读基础协议与结构，再看 JobsBaseCor/Font 和 JobsTheme，最后沿组件调用看登记与通知关系。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsBaseProtocolDefs.swift](<./JobsBaseProtocolDefs.swift>)
- [JobsBaseCor.swift](<./JobsBaseCor.swift>)
- [JobsTheme.swift](<./JobsTheme.swift>)
- [JobsSwiftBlockBridge.swift](<./JobsSwiftBlockBridge.swift>)
- [JobsBaseCellConfig.swift](<./JobsBaseCellConfig.swift>)

依赖与编译入口：[JobsSwiftBaseDefines.podspec](<./JobsSwiftBaseDefines.podspec>)。其中显式依赖声明包括 `JobsSwiftBlock`、`JobsTextTools`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
