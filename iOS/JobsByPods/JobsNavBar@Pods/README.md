# <font id=前言>JobsNavBar</font>

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

提供独立的自定义导航栏视图，以样式与布局组织左右区域、标题及加载提示，并保留与网页标题等外部状态联动的入口。它是页面内的导航 UI，不单独拥有应用导航栈。

### 2.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

配置样式和按钮 → 安装导航栏约束 → 绑定标题或加载状态 → 用户操作交给宿主处理

### 2.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 标题定位需要考虑左右容器的实际宽度，不能只用整屏居中造成文字与按钮重叠。
- 布局约束的首次安装和配置变化后的更新应分开，避免每次刷新都叠加约束。
- 网页标题提供者、加载兜底文案和返回行为属于独立配置点，不能假设任意返回按钮都等于直接 pop。
- 安全区与导航栏内容高度应在宿主布局中保持一致，避免重复补顶部间距。

### 2.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 JobsNavBar 的样式和公开配置，再看布局、标题刷新与按钮动作。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsNavBar.swift](<./JobsNavBar.swift>)
- [JobsNavBarByUIKit.swift](<./JobsNavBarByUIKit.swift>)
- [JobsNavBarDef.swift](<./JobsNavBarDef.swift>)
- [JobsNavBarTools.swift](<./JobsNavBarTools.swift>)

依赖与编译入口：[JobsNavBar.podspec](<./JobsNavBar.podspec>)。其中显式依赖声明包括 `SnapKit`、`JobsSwiftBlock`、`JobsSwiftBaseDefines`、`SwiftMessages`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
