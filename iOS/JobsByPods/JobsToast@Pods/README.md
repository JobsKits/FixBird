# <font id=前言>`JobsToast@Pods`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---
> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

## 一、Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## 二、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 2.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

通过 Config 描述提示时长、边距、偏移和外观，JobsToast 负责展示、点击与消失。窗口关联记录当前提示，新的提示进入时处理已有实例，便利入口统一调用方式。

### 2.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

配置文字和样式 → 找到展示窗口 → 处理已有提示并展示 → 点击或超时 → 消失并清理关联

### 2.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 每个窗口的当前提示记录需要与实例保持一致，旧提示的延迟清理不能误清除新提示。
- 点击回调与完成回调含义不同，自动结束和手动 dismiss 都要明确收尾。
- 便利字符串入口允许任意线程调用，真正的 UI 操作仍需切回主线程。
- Toast 只是提示，不负责业务操作成功判定，也不应长期占用窗口或阻断底层交互。

### 2.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 Config 与 show，再跟踪 dismiss、窗口关联清理和回调。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsToast.swift](<./JobsToast.swift>)

依赖与编译入口：[JobsToast.podspec](<./JobsToast.podspec>)。其中显式依赖声明包括 `SnapKit`、`JobsByUIKit`、`JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
