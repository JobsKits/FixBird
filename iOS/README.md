# <font id=前言>[**iOS**](https://developer.apple.com/ios/) 原生端</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

使用 <u>[**Swift**](https://www.swift.org/)</u> / [**UIKit**](https://developer.apple.com/documentation/uikit) 按 `JobsSwiftBaseConfigDemo` 的组织方式平移，支持用户 / 师傅账号和独立本地演示。

## 一、工程组成 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `App/`：App / Scene 入口与 Info.plist。
- `App/Domain/`：订单、身份会话、师傅申请、设备授权和模拟账务模型，包含输入校验、整数分金额与请求上下文；每个主体独立目录。
- `App/Modules/`：基于 `BaseVC` 的主控制器，首页 / 订单 / 设置 / 表单 / 组件扩展，以及独立订单卡片、表单和 UI 工厂。控件使用 Jobs 类级创建、链式 DSL 与 [**SnapKit**](https://github.com/SnapKit/SnapKit)，固定控件懒加载，动态控件由页面强持有。
- `App/Services/`：环境配置、JobsNetworking 网络边界、账号 / 审核 / 账务 / 设备 / 扫码独立仓储、Keychain 会话与隔离缓存；业务层与网络、持久化实现分离。
- `App/Resources/`：开屏 SVG、主题 [**JSON**](https://www.json.org/json-en.html)、简体中文和英文字符串。
- `App/Resources/Assets.xcassets/AppIcon.appiconset/`：使用 [**iconfont**](https://www.iconfont.cn/) Logo 生成的 1024×1024 应用图标。
- `App/Resources/Assets.xcassets/RepairLogo.imageset/`：[**iconfont**](https://www.iconfont.cn/) Logo 的本地兜底资源。
- `JobsByPods/`：基准工程中选取的 Jobs 自建本地 Pods；未复制第三方手工集成目录。
- [`ScriptsByPods/`](<ScriptsByPods/【MacOS@Xcode】🫘打开终端运行Pod Install.command/README.md>)：[**Xcode**](https://developer.apple.com/xcode) 手动 `pod install` 入口，采用同名脚本目录、脚本和 README 的组织方式。
- `Podfile`：平台、工程 target 和依赖清单挂载钩子。
- `Podfile.deps`：按一行一个 Pod 拆出的本地 / 外部依赖。
- `RepairMarketplace.xcodeproj`：[**iOS**](https://developer.apple.com/ios/) app project；执行 [**CocoaPods**](https://cocoapods.org/) 后使用 workspace 打开。

## 二、运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```sh
cd .
pod install
open RepairMarketplace.xcworkspace
```

也可从 Xcode 的 `Behaviors → 🫘啄木鸟 iOS · Pod Install` 随时启动 [手动安装脚本](<ScriptsByPods/【MacOS@Xcode】🫘打开终端运行Pod Install.command/README.md>)。它按自身位置定位当前 iOS 工程，打开终端显示中文自述，按回车确认后检查 `pod --version` 并执行 `pod install`；`Ctrl+C` 取消。完整输出同步到系统临时目录中的 `repair-marketplace-pod-install.log`，每次确认后覆盖。

File Navigator 的 `ScriptsByPods` 组可查看和编辑脚本；文件只作工程引用，不加入 App target、Build Phase 或 Scheme 自动动作。自定义 Behaviors 属于 Xcode 当前用户设置，换电脑或迁移项目路径后需重新选取脚本；具体配置步骤见上述脚本 README。入口不依赖 [**Sourcetree**](https://www.sourcetreeapp.com/)，不自动安装或升级 CocoaPods、[**Ruby**](https://www.ruby-lang.org)、[**Homebrew**](https://brew.sh/)，也不触发构建。

`Podfile.deps` 由 `Podfile` 的 `post_install` 钩子挂到 `Pods.xcodeproj` 根组，使用 `explicitFileType = text.script.ruby` 显示红钻，只添加文件引用，不加入 Build Phase。钩子会重新打开工程，检查根对象、唯一引用和引用类型；失败时恢复备份并告警跳过，不阻断 `pod install`。重复安装会复用已有引用。

头 URL 统一配置在 `App/Services/MarketplaceEnvironment/MarketplaceEnvironment.swift`，业务层只拼接 `/api/v1/...`。Debug 默认本机测试：模拟器使用 `http://127.0.0.1:8080`，真机默认使用当前 Mac 的 `http://192.168.1.7:8080`；Release 固定线上配置 `productionBaseURL`，目前保留空字符串，填好后重新编译即可。请求超时为 2 秒，不自动重试。

页面进入和点击固定的“重新加载”按钮均请求服务端。订单首屏先展示上次成功快照；没有快照时立即展示 [**UserDefaults**](https://developer.apple.com/documentation/foundation/userdefaults) 本地样例。成功响应完整替换该身份快照，空数组同样覆盖旧订单；失败、超时或解析失败时展示独立本地演示。服务恢复后的下一次成功请求自动替换为真实数据。列表明确提示最多显示最近 200 条，尚未提供历史翻页；“重新加载”始终请求最新 200 条，不能用于判断全部历史订单数量。

服务端快照与演示仓储使用不同存储键，并按环境、头 URL、角色和 actor ID 隔离。旧版混合缓存只保留 `demo-` 开头的演示记录，真实记录重新从 API 获取。用户 / 师傅演示身份可互相体验同一演示订单；本地演示不写入真实快照，也不自动重放到服务端。

创建、接单、登记到场、报价、确认报价、取消和完工均先请求 API。请求失败仍可本地演示，同时保留明确的结果说明：4xx 拒绝展示状态码及原因；超时、写响应丢失或解析失败说明“服务端结果未知”，提醒先核实真实订单。针对真实订单的失败操作生成不同 ID 的演示副本；页面的“本地演示结果（不会同步）”区域保留操作结果，后续 GET 成功也不会掩盖此前写失败。可以关闭展示，也可以手动重开失败的下单表单。真实支付渠道尚未接入。

首次进入业务首页前必须先在身份入口选择用户或师傅，然后登录或注册对应账号；显式选择本地演示也先确认角色。有效会话恢复后进入该账号唯一身份的首页；业务首页不展示双角色切换按钮。“我的 → 头像 → 切换身份”退出当前设备并回到身份入口，再登录另一身份账号，不会把用户账号直接升级为师傅。头像内同时提供本人密码修改，成功后旧会话撤销并回到登录入口。用户名为 3 至 64 位 ASCII 字母、数字、下划线、点或横线；新密码为 12 至 128 个字符且不超过 256 UTF-8 字节。登录请求声明手机设备，实际角色和管理能力以服务端返回为准；已登录账号不能通过客户端角色按钮切换权限。Token 和会话只保存到 [**Keychain**](https://developer.apple.com/documentation/security/keychain_services)，按环境和服务地址隔离，不保存密码，不把 Token 写入 UserDefaults。认证失败保持未登录，显式点击“本地演示账号”才进入演示身份。

“师傅资料与审核”填写称呼、联系方式、服务区域、维修技能和可选简介，上传 1 至 6 张本人资质图片，提交后等待后台人工审核。图片经宿主 UIImage 工厂扩展在后台线程压缩，最长边不超过 2048 像素并逐步编码至 2 MiB 内，以现有 JobsNetworking multipart 上传；私有图片通过 Bearer API 返回二进制，不生成公开 URL、不保存到偏好缓存。只由后台管理员审批，手机只能查询状态或修改重提；重提已通过的资料会恢复待审核并暂停新接单。接口失败只保存独立的本地待审核演示及演示附件 ID，不能生成“已通过”，也不会自动补交。未申请的 404 + `code=not_found` 显示正常空态。

“我的账务与分润”只查询本人模拟收款、分润和人工核销流水。汇总为本人全部模拟账本的净发生额，流水最多显示最近 200 条；暂未提供历史翻页。人工核销只是记账，不会发起转账，汇总不能解释为银行余额。接口失败显示明确标注的独立空账务演示，保留服务端快照；成功空数组会覆盖旧流水。所有私有缓存按环境、服务地址、角色和账号 ID 隔离，真实账号的本地演示不会流入匿名演示角色。

“登录设备”查询本人会话，仅服务端授予 `manage_devices` 的手机密码会话可撤销指定设备。退出当前手机只撤销当前会话，电脑与其它手机继续有效；断网退出会清除本机凭据，并明确提示服务端注销未确认。迟到注销响应不会清除之后新登录的会话。

“扫码登录授权”提供 [**AVFoundation**](https://developer.apple.com/documentation/avfoundation) 相机扫码和粘贴登录 URI 两个入口，模拟器可使用粘贴方式。只接受 `repairmarketplace://login?challengeId=...&approvalCode=...`，先请求 inspect 显示电脑名称、平台及到期时间，再由本人明确确认批准或拒绝。扫描和检查不会自动授权；二维码秘密只保留在当前页面内存并放入请求体，不能持久化或进入 URL 日志。仅具有 `authorize_qr` 能力的手机密码会话可授权，扫码电脑会话不具备设备管理或继续授权扫码的能力。结果未知时提示核对电脑状态，不自动重试。

同一保留表单第一次实际尝试提交时记录 UUID，请求通过 `Idempotency-Key` 发送；相同内容手动重试复用编号，修改内容或新建表单使用新编号。未知结果必须先核实订单；页面不自动重试或补交演示记录。设备、故障描述、地址必填，按与服务端一致的 Unicode scalar 数量分别限制 160 / 4000 / 500 字。预约时间允许空；非空须填写带时区的 RFC3339，例如 `2026-10-05T14:00:00+08:00`。报价使用十进制转整数分，允许 0.01 至 1,000,000 元、最多两位小数；超长数字、非有限值、负值及超过上限会提示错误。

订单列表无数据时通过 Jobs `JobsEmptyAuto.Config.defaultProvider()` 创建 UIButton 空态按钮，并提供重新加载动作。Logo 先从 Assets Catalog 本地显示，再经 Jobs `JobsImageLoader` 请求 [**iconfont**](https://www.iconfont.cn/) 图片；网络加载失败时继续展示随包 Logo。

Debug 通过本地 [`JobsDebugPanel`](JobsByPods/JobsDebugPanel@Pods/README.md) 替代原 `EnvironmentFloatingWindow` / `EnvironmentDebugViewController`。`AppDelegate` 调用 `MarketplaceDebugPanel.start()` 配置圆形背景图 UIButton；点击 push 功能表，再次点击关闭面板及其环境列表、自定义子页，返回打开前的业务页面；面板上的弹窗先安全关闭，再返回业务页。拖动时保持在安全区域内且不会误触菜单或长按隐藏；长按仅隐藏到本次进程结束，重启恢复。面板与环境列表跟随宿主 JobsThemeCenter，已打开页面即时更新，App 与系统主题不同时也保持一致。Pod 只在 Debug 依赖，源码与 App 初始化也均由 `#if DEBUG` 隔离。

功能按配置顺序展示：

1、`App 环境切换`：push 二级 URL 选择列表。

2、`修改本机测试地址`：沿用 URL 校验、`保存并刷新` 和持久化地址；“我的 → 配置服务地址”调用同一入口。

3、`查看当前环境`：显示业务层当前生效的环境与头 URL。

4、`线上配置状态`：明确提示尚未配置的线上 URL。

Debug 环境列表只接受真实有效的 HTTP / HTTPS URL，当前 `productionBaseURL` 仍为空，因此默认展示有效的本机测试环境；此前保存的未配置线上选择会回退本机测试，不会宣称已连上线上服务。测试 / 线上枚举和原地址常量均保留，填入真实线上 URL 后二级列表自动增加线上选项。Release 仍固定使用 `productionBaseURL`，不读取 Debug 选择或自定义本机地址；线上未配置时继续本地演示，不拼相对 URL，也不发送伪造线上请求。

地址更新和环境选择仍统一调用 `MarketplaceEnvironment.select`：切换后关闭旧环境表单并重建业务页，增加环境 revision。读取请求还核对页面 revision 和角色，刷新或切换页面会取消旧读取请求；迟到回调不能刷新新页面或产生错位弹窗。圆按钮使用 Pod 打包的 [**Ant Design**](https://ant.design/) MIT 资源；透明区域穿透触摸，业务弹窗上方点击可安全返回工具列表。

iPhone 与 Mac 需在同一局域网，允许 App 的本地网络访问；IP 变化时更新测试地址与 Docker 的 `API_LAN_BIND_ADDRESS`。真机联调启动命令见 [`Deployment/Docker/Shared/README.md`](../Deployment/Docker/Shared/README.md)。本次保留回环入口并额外绑定 `192.168.1.7:8080`，数据库仍只监听回环地址。服务恢复后重新进入页面或点空态按钮即可由成功响应自动切换到服务端数据。

支付按钮处于禁用态。网络请求统一通过 `JobsNetworking` 发出；`JobsNetworking` 内部以 [**Alamofire**](https://github.com/Alamofire/Alamofire) 5 实现，业务层不直接调用 [**AFNetworking**](https://github.com/AFNetworking/AFNetworking)。当前应用没有使用 JobsSwiftDSL / JobsSwiftBlock 中为旧 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) 保留的适配器，因此本工程不再安装 [**YTKNetwork**](https://github.com/yuantiku/YTKNetwork) / [**AFNetworking**](https://github.com/AFNetworking/AFNetworking)；适配源码仍受 `canImport` 保护。

`JobsThemeCenter`、`Jobsl10n`、`JobsSwiftSplash` 与 `JobsNetworking` 的使用位置分别在启动入口、界面模块、`SceneDelegate` 和 `MarketplaceAPI`。固定文案和服务分类支持简体中文 / 英文，组合标题先翻译各部分；用户填写的地址和故障描述保留原文。开屏跳过按钮跟随 App 内语言，“我的”中开屏开关显示下一次点击执行的动作。

## 三、编译产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

主 App target 最后一个 `Save Build IPA` Build Phase 会在 App 编译完成后调用 `ScriptsByDevTools/save_device_ipa_after_build.command/save_device_ipa_after_build.command`，将本次构建结果写入 `build/`：

| [**Xcode**](https://developer.apple.com/xcode) 目标平台 | 构建产物 |
| --- | --- |
| [**iOS**](https://developer.apple.com/ios/) 模拟器 | `build/模拟器.ipa` |
| [**iOS**](https://developer.apple.com/ios/) 真机 | `build/真机.ipa` |

工程使用自定义 `App/Info.plist` 且关闭自动生成 Info.plist，因此必须显式保留 `CFBundleExecutable = $(EXECUTABLE_NAME)`；否则 App 二进制虽已生成，iPhone 安装仍会因 `MissingBundleExecutable` 被拒绝。

脚本先把 `.app` 复制到系统临时目录的 `Payload/<App名>.app`。真机包必须有有效的 [**Xcode**](https://developer.apple.com/xcode) 签名身份，并通过严格签名校验；模拟器允许关闭代码签名。压缩、签名校验全部成功后，脚本清空 `build/`（包含隐藏文件、子目录、旧包和另一平台的包），只保留本次生成的 IPA。签名或压缩失败时不会先清理旧产物。脚本日志同时显示在 [**Xcode**](https://developer.apple.com/xcode) 构建日志和系统临时目录的 `save_device_ipa_after_build.log`。

`模拟器.ipa` 只是模拟器 `.app` 的 Payload 快照，不能安装到真机或用于正式分发；`真机.ipa` 的可安装范围取决于签名与描述文件，正式发布仍需通过 Archive / Organizer 导出。DerivedData、构建中间目录和 App 源产物必须放在 `build/` 外。该阶段位于主 App target 的最后一个 Build Phase；它成功运行代表 IPA 阶段完成，不代表后续 Scheme 动作或测试全部成功。

脚本与专属说明位于 `ScriptsByDevTools/save_device_ipa_after_build.command/`，参见 [脚本 README](./ScriptsByDevTools/save_device_ipa_after_build.command/README.md)。Xcode 构建入口仍打印自述后自动执行；独立终端运行需先回车确认，再输入 `YES` 同意成功打包后的 build/ 清空，没有可交互输入则退出。确认前不初始化日志，也不修改产物。

## 四、业务回归验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在当前目录运行：

```sh
ruby Tests/run_core_tests.rb
```

需要 [**Ruby**](https://www.ruby-lang.org) 和可调用的 `swiftc`；可通过 `SWIFTC` 指定编译器路径。脚本在系统临时目录编译真实领域模型、提交编号、仓储、状态迁移和缓存，仅替换网络、系统 Keychain 边界与存储介质。覆盖金额精度及上限、空快照覆盖、拒绝 / 未知结果、独立演示、状态迁移、表单幂等键、环境 / 角色 / actor 隔离、旧缓存筛选、服务恢复及预约时间校验；另覆盖认证失败不伪造登录、凭据保存失败、手机管理能力、审核 null 时间及本地待审核隔离、私有图片演示 ID、账务空态、单设备撤销、严格二维码解析 / 检查 / 决策及迟到退出竞态。测试不发送网络请求，不读写真实 Keychain，不写 App 的 UserDefaults，不安装 Pods，不调用 `xcodebuild`，不生成或清理 IPA。

完整编译验证应使用工程临时副本，将副本的 `Save Build IPA` 阶段移除并把 DerivedData 放到临时目录，再分别构建 Debug / Release；保留真实工程的打包阶段。该方式验证源码、依赖和配置，不能替代真机签名、安装、页面交互及 IPA 分发验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
