# `JobsDebugPanel`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

<u>[**Swift**](https://www.swift.org/)</u> 调试工具：屏幕前方的圆形按钮 push 出功能列表，再次点击关闭面板并返回打开前的页面，默认功能为 App 网络环境切换。长按按钮只隐藏到本进程结束，下次启动自动恢复。

## 一、接入与配置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**CocoaPods**](https://cocoapods.org/) 仅在 Debug 依赖，并且所有源码均有 `#if DEBUG`；Release 不初始化、不链接此 Pod，也不展示 Demo 入口。

  ```ruby
  pod 'JobsDebugPanel', :path => 'JobsByPods/JobsDebugPanel@Pods', :configurations => ['Debug']
  ```

- 在 `AppDelegate` 的 Debug 启动路径配置 URL 与备注，再注册自定义功能。默认环境项排在第一行，自定义项按 `byAddAction` 的调用顺序排列。图片可不配置，点击闭包得到当前功能列表 VC，可继续 push 或执行操作。

  ```swift
  #if DEBUG
  import JobsDebugPanel
  import JobsByUIKit

  JobsDebugPanel.shared
      .byEnvironments([
          JobsDebugEnvironment()
              .byIdentifier(MarketplaceEnvironment.test.rawValue)
              .byTitle(MarketplaceEnvironment.test.title)
              .byBaseURL(MarketplaceEnvironment.testBaseURL)
      ])
      .byEnvironmentDidChange { environment in
          guard let selected = MarketplaceEnvironment(rawValue: environment.identifier),
                MarketplaceEnvironment.current != selected else {
              return
          }
          MarketplaceEnvironment.select(selected)
      }
      .byAddAction(
          JobsDebugAction()
              .byTitle("修改本机测试地址")
              .byImage(nil)
              .byAction { sourceVC in
                  MarketplaceDebugPanel.presentAddressEditor(from: sourceVC)
              }
      )
      .byStart()
  #endif
  ```

## 二、环境与窗口行为 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 环境只接受带有效 host 的 HTTP / HTTPS URL。无效条目自动过滤；保存的 URL 不在当前配置中时回退到首个有效环境。持久化键为 `JobsDebugPanel.Debug.SelectedEnvironmentURL`，只由 Debug 代码读取与写入。
- 切换后立即调用 `byEnvironmentDidChange`，并发出 `environmentDidChangeNotification`。框架不绑定某个网络栈；本宿主由 `MarketplaceDebugPanel` 桥接到 `MarketplaceEnvironment.select`，后续业务请求新建 agent 时读取当前 URL。环境 revision、缓存按环境和 URL 隔离、旧请求不得覆盖新环境均沿用原业务实现。
- 各前台活跃 Scene 都有独立的透明 UIWindow；未启用 Scene 的宿主从 AppDelegate 的 window 接入。它不抢宿主 keyWindow，圆按钮之外的触摸穿透；按钮点击使用其所属 Scene 的宿主窗口导航栈，并沿抽屉等自定义容器的可见子控制器解析。无导航栈时先展示临时导航容器，在展示完成后 push 功能列表；返回会关闭临时容器。
- 业务 `UIAlertController` 显示期间也能点击圆按钮；先安全关闭该弹窗，不执行其业务 action，再解析当前宿主并 push 工具列表。
- 从自定义功能再次打开面板时，优先返回导航栈内已有的功能列表，避免重复创建与宿主的安全 push 去重冲突。
- 圆按钮再次点击时关闭本次面板导航，环境列表及自定义 push 子页一并退出；面板上的模态页面先关闭，再返回打开前的页面。无宿主导航栈时直接关闭临时容器。宿主切换环境并重建根控制器后，旧面板记录不影响下一次打开；公开 `open(from:)` 仍保持打开语义。
- 面板和环境列表跟随宿主 `JobsThemeCenter` 的有效主题；页面背景、单元格、文字、选中态和原生附件同步更新，App 外观与系统外观不同时也保持一致。已打开的面板随主题切换即时更新。
- 圆按钮可单指拖动，位置限定在当前窗口安全区域内；旋转或窗口尺寸变化时重新限制位置。拖动不会打开菜单或触发长按隐藏，拖动后仍可点击打开；位置仅在当前 Scene 的本次启动内保留。
- 圆按钮的长按隐藏状态只存在内存中，不写入持久化配置。背景图来自打包资源，无文字、无运行时网络图片。

## 三、Demo 与离线预览 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 维修宿主的 `AppDelegate` 初始化 `App/Debug/MarketplaceDebugPanel/MarketplaceDebugPanel.swift`，菜单顺序为 `App 环境切换`、`修改本机测试地址`、`查看当前环境`、`线上配置状态`；“我的 → 配置服务地址”复用同一编辑入口。
- 测试 URL 沿用模拟器 `http://127.0.0.1:8080` / 真机 `http://192.168.1.7:8080` 与已保存的有效自定义地址。`productionBaseURL` 仍为空，只展示未配置状态；配置真实线上 URL 后自动进入二级列表。Pod 恢复保存的有效 URL，无效或尚未配置的旧线上选择回退本机测试。
- 业务进入、刷新和写操作照常通过 `JobsNetworking` 请求当前头 URL 的 `/api/v1/...`，超时为 2 秒且不自动重试；成功替换本地样例，失败、超时或解析失败继续本地演示。缓存按环境和 URL 隔离，切换递增 revision 保护旧响应。
- Release 固定读取线上配置，不读取 Debug 环境选择或自定义测试地址；线上未配时不发出伪造请求，继续本地演示。环境列表完全无有效配置时显示 `JobsEmptyAuto` 按钮空态与重新加载入口。

## 四、弱网边界与资源来源 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 不提供“全 App 弱网”开关：普通 [**iOS**](https://developer.apple.com/ios/) App 无法通过公开 API 全局控制系统网络带宽、延迟和丢包；只延迟某个请求回调无法覆盖 WebSocket、媒体流和其它请求栈。需要真实弱网测试时，开发者可手动使用系统 [**Network Link Conditioner**](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/TestingPerformance.html)。[**URLProtocol**](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/protocolclasses) 的局部拦截也不适用于后台 URLSession，不能据此宣称完整弱网覆盖。
- 素材先检索 [**iconfont**](https://www.iconfont.cn/)，未能确认匹配图标的作者许可，改用 [**Ant Design Icons**](https://github.com/ant-design/ant-design-icons) 官方 `filled/bug.svg`，MIT 许可。
- `Resource/JobsDebugPanelButton.svg` 使用官方图形路径配合圆底本地渲染为 `Resource/JobsDebugPanelButton.png`；PNG 是实际打包背景图，SVG 为可追溯源文件。许可证为 `Resource/AntDesignIcons-LICENSE`。宿主 Debug Demo 入口通过只读 `JobsDebugPanel.buttonImage` 复用 Pod 图片，无宿主 Asset Catalog 副本，Release 不打包该图标。
- 官方源：[bug.svg](https://github.com/ant-design/ant-design-icons/blob/master/packages/icons-svg/svg/filled/bug.svg)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
