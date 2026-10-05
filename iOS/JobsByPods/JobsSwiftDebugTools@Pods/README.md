# <font id=前言>`JobsSwiftDebugTools`</font>

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、介绍 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 用**Toast**的方式来<font color=red>检验目标 **`UIViewController`** 是否释放</font>

* 利用协议挂载，没有入侵性

* 文案有默认值，亦可以在当前**`UIViewController`**中自定义文案

* 不占用当前的 `deinit{/// TODO}`方法

* 只在**Debug**环境下生效，能在**Release**环境下打包

* `VCDebugDeallocDebug.showsDeinitTips` 持久化控制销毁 Toast 是否显示，默认开启；关闭后仍保留控制器销毁与日志清理流程

* 第三方引用

  ```ruby
  s.source_files = '**/*.{swift,h,m,mm}'
  s.dependency 'JobsSwiftBaseDefines'
  s.dependency 'JobsByUIKit'
  s.dependency 'JobsToast'
  ```

## 二、使用方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

* 引入框架 **`JobsSwiftDebugTools`**

  ```swift
  #if DEBUG
  import JobsSwiftDebugTools
  #endif
  ```

* App入口处进行调用 **➤**  **`AppDelegate.swift`**

  ```swift
  #if DEBUG
  VCDebugDeallocDebug.install()
  #endif
  ```

* 在应用设置页或调试面板中切换销毁提示

  ```swift
  VCDebugDeallocDebug.showsDeinitTips.toggle()
  ```

<a id="jobs-architecture"></a>

## 三、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 3.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

通过控制器生命周期 Hook 绑定关联观察对象，在观察对象销毁时输出控制器销毁信息，并提供日志与可配置 Toast 提示。安装入口与显示开关分离。

### 3.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

应用早期安装 Hook → 控制器加载时绑定观察对象 → 控制器释放 → 观察对象 deinit 记录并按开关提示

### 3.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 当前观察方式交换 viewDidLoad 并关联监听器，不是直接替换控制器 dealloc。
- 安装应只执行一次；关闭销毁 Toast 不等于停止观察和日志清理流程。
- 提示开关持久化，默认保持原有开启行为，调试面板应调用公开入口调整。
- 有销毁提示可辅助确认释放，但没有提示不能单凭现象就判定内存泄漏，还需核对安装与开关。

### 3.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 VCDebugDeallocDebug.install 与显示开关，再看关联观察对象、一次性交换及自动加载入口。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [UIViewController+DebugDeallocSwizzle.swift](<./UIViewController+DebugDeallocSwizzle.swift>)
- [JobsDebugDeinitAutoLoad.m](<./JobsDebugDeinitAutoLoad.m>)
- [JobsDebugLog.swift](<./JobsDebugLog.swift>)

依赖与编译入口：[JobsSwiftDebugTools.podspec](<./JobsSwiftDebugTools.podspec>)。其中显式依赖声明包括 `JobsSwiftBaseDefines`、`JobsByUIKit`、`JobsToast`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
