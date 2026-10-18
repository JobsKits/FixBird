# <font id=前言>`JobsImageTools`</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、架构脉络与关键设计](#jobs-toc-heading-1)
  - [1.1、设计目的与职责划分](#jobs-toc-heading-2)
  - [1.2、运行脉络](#jobs-toc-heading-3)
  - [1.3、关键设计与边界](#jobs-toc-heading-4)
  - [1.4、阅读与重建顺序](#jobs-toc-heading-5)

</details>
<!-- jobs-toc:end -->

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

<a id="jobs-architecture"></a>

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### <span id="jobs-toc-heading-2" data-jobs-toc="v2">1.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

分开处理简单图片加载、Kingfisher/SDWebImage 缓存清理，以及对现有 [**UIKit**](https://developer.apple.com/documentation/uikit) 视图树的图片刷新。核心不是重新实现图片框架，而是记录与协调实际加载来源。

### <span id="jobs-toc-heading-3" data-jobs-toc="v2">1.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

记录控件图片来源及加载器 → 发起图片加载 → 按需清理缓存 → 遍历已记录来源的控件重新请求

### <span id="jobs-toc-heading-4" data-jobs-toc="v2">1.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 同时存在两种图片框架时，应按每个控件记录的 jobs_imageLoaderKind 选择刷新方式，不能通过编译分支只处理其中一种。
- 强制重新下载依赖控件记录的远程地址，无法从任意 UIImage 反推出原始 URL。
- 缓存删除与屏幕上已显示图片更新是两件事；UIImageView、按钮前景图和背景图需要分别处理。
- UI 树遍历与控件更新遵循主线程要求，下载与磁盘缓存的完成时机应通过回调衔接。

### <span id="jobs-toc-heading-5" data-jobs-toc="v2">1.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

先看 JobsSimpleImageLoader，再看 JobsImageCacheCleaner，最后读 ByUIKit 中如何找控件和恢复加载。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsImageCacheCleaner.swift](<./JobsImageCacheCleaner.swift>)
- [JobsSimpleImageLoader.swift](<./JobsSimpleImageLoader.swift>)
- [JobsImageCacheCleanerByUIKit.swift](<./JobsImageCacheCleanerByUIKit.swift>)

依赖与编译入口：[JobsImageTools.podspec](<./JobsImageTools.podspec>)。其中显式依赖声明包括 `Kingfisher`、`SDWebImage`、`JobsSwiftBlock`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
