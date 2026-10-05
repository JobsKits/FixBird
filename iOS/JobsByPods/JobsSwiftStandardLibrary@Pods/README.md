# <font id=前言>`JobsSwiftStandardLibrary`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## 一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

按容器、整数、浮点和 Optional 等类型组织标准库扩展。当前已有数组构建与部分便利操作、默认初始化协议适配，同时也存在仅有文件头的类型占位，目录数量不代表能力数量。

### 1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

选择值或容器类型 → 调用已有扩展 → 返回新值或原地修改 → 上层决定缺省值含义

### 1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- Array.add 返回新数组，addBy 原地修改；Builder 提供闭包内链式构建，两种 addBy 的接收类型不同。
- Builder 持有临时数组指针，使用范围应限制在 build 闭包中，不应逃逸后继续调用。
- Optional 的默认初始化适配不等于业务数据一定有效，空字符串、零值与缺失值仍有不同含义。
- 例如 Int.swift 当前只含文件头，重建时不能给所有预留类型凭空补一套不存在的方法。

### 1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先看 Optional.swift 与容器/Array.swift 的实际实现，再逐文件确认其他扩展是否已有正文。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [Optional.swift](<./Optional.swift>)
- [容器/Array.swift](<./容器/Array.swift>)
- [容器/Collection.swift](<./容器/Collection.swift>)
- [容器/Dictionary.swift](<./容器/Dictionary.swift>)
- [容器/Sequence.swift](<./容器/Sequence.swift>)

依赖与编译入口：[JobsSwiftStandardLibrary.podspec](<./JobsSwiftStandardLibrary.podspec>)。其中显式依赖声明包括 `JobsSwiftBaseDefines`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
