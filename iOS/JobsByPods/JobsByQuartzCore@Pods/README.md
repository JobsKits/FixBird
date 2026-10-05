# <font id=前言>`JobsByQuartzCore@Pods`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---
> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

## 一、DSL 迁移说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 本 Pod 原有的链式 DSL / 点语法封装已经抽离到 `JobsSwiftDSL`。
- 继续使用 `byXxx(...)`、`dsl { ... }` 这类语法时，请在调用文件显式 `import JobsSwiftDSL`。
- 本 Pod 保留薄桥接文件和 `JobsSwiftDSL` 依赖，用于兼容旧代码的过渡期。

<a id="jobs-architecture"></a>

## 二、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 2.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这是 [**QuartzCore**](https://developer.apple.com/documentation/quartzcore/cadisplaylink) 链式扩展迁移后的模块入口。当前本目录保留 JobsByQuartzCore.swift，实际 DSL 由 JobsSwiftDSL 承载，基础定义和回调类型由相应基础 Pod 提供。

### 2.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

宿主引入模块 → 找到 JobsSwiftDSL 的 [**QuartzCore**](https://developer.apple.com/documentation/quartzcore/cadisplaylink) 扩展 → 配置系统图层或动画对象

### 2.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 本 Pod 不包含一套独立动画调度引擎，不应把名称理解成所有动画行为都在这里实现。
- 重建时保留依赖方向，不要同时在兼容 Pod 和 DSL Pod 中复制相同扩展。
- 图层对象的配置能力与动画播放、暂停、销毁等行为应按实际实现分别定位。

### 2.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

从模块入口和 podspec 开始，再沿依赖到 JobsSwiftDSL 的 [**QuartzCore**](https://developer.apple.com/documentation/quartzcore/cadisplaylink) 目录。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsByQuartzCore.swift](<./JobsByQuartzCore.swift>)

依赖与编译入口：[JobsByQuartzCore.podspec](<./JobsByQuartzCore.podspec>)。其中显式依赖声明包括 `JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
