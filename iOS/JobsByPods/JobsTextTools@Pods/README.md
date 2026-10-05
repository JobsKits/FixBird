# <font id=前言>`JobsTextTools`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

用 JobsText 统一承载纯文本和富文本，再由 JobsRichRun 描述文本片段或附件，JobsRichText 将片段及段落样式拼成可显示的富文本。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

建立纯文本或富文本载体 → 组合片段和附件 → 应用段落样式 → 输出所需文本形式

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 将富文本取为 String 会丢失样式，仅保留字符内容；调用方应主动选择输出形式。
- 附件、文本片段与整体段落样式有不同作用范围，不能把全部样式只施加到最后一个片段。
- JobsText 的存储使用 unchecked Sendable 适配，不能因此假定共享可变富文本可以无约束并发修改。
- 基础载体和 [**UIKit**](https://developer.apple.com/documentation/uikit) 富文本构建器的依赖边界不同，阅读时先确定是否需要图像附件。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 JobsText.Storage 与转换入口，再看 JobsRichRun.Payload 和 JobsRichText.make 的拼装。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsRichText.swift](<./JobsRichText.swift>)
- [JobsText.swift](<./JobsText.swift>)

依赖与编译入口：[JobsTextTools.podspec](<./JobsTextTools.podspec>)。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
