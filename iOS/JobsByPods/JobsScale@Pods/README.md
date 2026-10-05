# <font id=前言>📏比例尺</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

* **JobsScale**主要是协调**iPhone**的不同设备屏幕和设计稿之间的比例转换问题

  * 对于UI宽高各一个比例尺（参考[**Flutter**](https://flutter.dev/)中关于屏幕的适配方案）

    ```swift
    3.w // 宽
    3.h // 高
    ```

  * 对于字体单独的一个比例尺

  * App启动时需要配置当前UI锚定的设计稿尺寸

    ```swift
    // MARK: - 比例尺
    JobsScale.setup(designWidth: 375, designHeight: 812)
    ```

  * 兼容**iPad**

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

将设计稿尺寸到当前显示尺寸的转换集中管理，宽高布局与字体缩放分别计算。字体支持连续比例或按屏幕宽度分档，窗口尺寸由 JobsGetWindow 辅助获取。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

启动时设置设计稿尺寸 → 获取当前显示尺寸 → 计算宽高比例与字体比例 → 供布局和字体入口使用

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 字体只看宽度，避免横屏或 iPad 上随高度比例异常变化；布局宽高不能混为一个比例。
- Safe Area 是布局约束，默认不作为全局比例尺；兼容开关取不到可靠窗口时会回退。
- 比例缩放不等于自动布局，宿主仍需处理安全区、旋转、分屏及内容固有尺寸。
- 启动配置必须先于业务使用，不能让不同页面各自偷偷修改全局设计稿基准。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 setup 与设计稿基准，再看 screenSize、UI 比例和字体分档策略，最后看便利数值入口。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsScale.swift](<./JobsScale.swift>)

依赖与编译入口：[JobsScale.podspec](<./JobsScale.podspec>)。其中显式依赖声明包括 `JobsGetWindow`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
