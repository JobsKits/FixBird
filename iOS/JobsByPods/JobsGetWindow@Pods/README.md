# <font id=前言>JobsGetWindow</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

- `UIWindowScene.keyWindowCompat` 统一处理 [**iOS**](https://developer.apple.com/ios/) 15+ `keyWindow` 与旧系统 `windows` 回退。
- `legacyKeyWindowPreiOS13()` 仅作为已退役的 Jobs 兼容入口保留，其 deprecated message 指向 Jobs 替代 API；底层系统版本差异由实现内部处理。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

封装多场景下的窗口选择与可见控制器查找。全局便利函数委托 UIApplication 和 UIWindowScene 扩展，在不同窗口和容器控制器之间寻找适合业务操作的入口。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

指定场景或使用默认选择 → 筛选并排序窗口 → 遍历展示和容器关系 → 返回可选窗口或控制器

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 多窗口环境不能永久缓存第一次获取的 keyWindow；需要确定场景时优先使用显式 scene 入口。
- 前台状态、窗口层级、主屏偏好与可见性共同影响选择，不能简化成 connectedScenes 的第一个元素。
- 可见控制器查找涉及导航、标签、分栏、分页与 presented 关系，并有忽略提示框的选项。
- 获取结果可能为空，调用方应保留降级路径，不能强制解包假定应用始终存在活动窗口。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 Inlines 中的公开入口，再看 UIApplication 的默认选择和 UIWindowScene 的局部查找。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Inlines.swift](<./Inlines.swift>)
- [UIApplication.swift](<./UIApplication.swift>)
- [UIWindowScene.swift](<./UIWindowScene.swift>)

依赖与编译入口：[JobsGetWindow.podspec](<./JobsGetWindow.podspec>)。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
