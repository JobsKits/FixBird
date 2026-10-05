# <font id=前言>`JobsByWebKit@Pods`</font>

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

当前是 WebKit DSL 的兼容模块，桥接入口依赖 JobsSwiftDSL；WebKit 系统对象的链式配置已经迁出。本目录不承载完整浏览器页面、下载中心或网页与原生通信系统。

### 2.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

引入兼容模块 → 调用 JobsSwiftDSL 的 WebKit 配置 → 由宿主或业务基类承接网页生命周期

### 2.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 需要网页容器、导航栏联动或桥接逻辑时，还应查 JobsInheritance 等实际使用方，不能都归入这个 Pod。
- 依赖 JobsByUIKit 不代表所有 [**UIKit**](https://developer.apple.com/documentation/uikit) 功能都由本目录实现。
- 复建时先恢复模块可见性和实际需要的 DSL，防止复制出两套同名扩展。

### 2.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 JobsByWebKitDSLBridge.swift，再看 JobsSwiftDSL 对应扩展，最后追具体网页容器的调用。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsByWebKitDSLBridge.swift](<./JobsByWebKitDSLBridge.swift>)

依赖与编译入口：[JobsByWebKit.podspec](<./JobsByWebKit.podspec>)。其中显式依赖声明包括 `JobsByUIKit`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
