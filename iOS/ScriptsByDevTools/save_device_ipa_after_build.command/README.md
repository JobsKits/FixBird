# `save_device_ipa_after_build.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

本脚本是啄木鸟维修平台原生 [**iOS**](https://developer.apple.com/ios/) 工程主 App 的自动 IPA 保存入口。[**Xcode**](https://developer.apple.com/xcode) 在最后一个 `Save Build IPA` 构建阶段调用它：真机生成 `../../build/真机.ipa`，模拟器生成 `../../build/模拟器.ipa`。签名与压缩成功后清空工程 `build/` 全部内容，仅保留本次唯一产物。

## 一、目录与执行前检查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
save_device_ipa_after_build.command/
├── save_device_ipa_after_build.command
└── README.md
```

- `./save_device_ipa_after_build.command`：系统 `/bin/zsh` 入口，脚本与本目录完整同名。
- `./README.md`：运行前阅读说明。
- `../../build/`：仅放一次性 IPA，不能保存源码、DerivedData、构建中间文件或其它需要保留的内容。
- 本机需具备可用 Xcode、系统 `ditto`、`mktemp`；真机包还需 `codesign` 与有效签名身份。脚本不安装或升级工具链。

App 源产物、日志、系统临时目录和所有构建中间目录必须位于 `../../build/` 外；输出目录不能是软链接。脚本采用 Xcode 提供的 `SRCROOT` 或 `PROJECT_DIR` 定位工程，不依赖启动目录，也不写死本机项目路径。

## 二、运行方式与确认 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

日常使用项目现有工作空间，在 Xcode 正常编译主 App 即可；构建阶段已经配置脚本输入路径和 `build/` 输出目录，仍位于主 App 最后一个 Build Phase。导航中的脚本与 README 仅供阅读，不加入源码或资源编译。

当 `XCODE_VERSION_ACTUAL` 与 `TARGET_BUILD_DIR` 同时存在时，脚本识别为已有 Xcode 构建入口：先打印内置自述，再无交互完成原自动流程，可取消当前构建。仅凭非终端或 `TERM=dumb` 不会跳过确认。

手动双击或终端运行时，先展示红色粗体标题、蓝色常规正文；按回车确认用途后，因成功打包会清空 `build/`，还必须输入 `YES` 才能继续。其它输入、读取失败或 `Ctrl+C` 都取消；没有交互输入且没有完整 Xcode 入口时直接退出。确认前不初始化日志、不打包、不清理产物。非 TTY、`TERM` 为空 / `dumb`、`NO_COLOR` 或 `PLAIN_OUTPUT=1` 使用纯文本。

终端位于本 README 目录时可运行：

```shell
./save_device_ipa_after_build.command
```

本脚本保存已有 App，不负责执行构建。手动运行仍须提供以下有效环境；如果同时提供上述 Xcode 入口标识，按自动构建模式执行。

| 变量 | 用途 |
| --- | --- |
| `SRCROOT` / `PROJECT_DIR` | 工程根目录，优先 `SRCROOT` |
| `TARGET_BUILD_DIR`、`WRAPPER_NAME` | 已构建的 App 目录与 `.app` 文件名 |
| `PLATFORM_NAME` | `iphoneos` 或 `iphonesimulator` |
| `ACTION`、`PRODUCT_TYPE` | 默认构建；`clean` 或非主 App 跳过 |
| `CODE_SIGNING_ALLOWED`、`EXPANDED_CODE_SIGN_IDENTITY` | 真机必须允许签名且身份非空、非 `-`；模拟器不要求真机身份 |
| `TMPDIR` | 系统临时目录；缺省回退 `/tmp` |

## 三、流程与产物边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

1、展示用途与清理范围，按 Xcode / 手动入口完成确认。

2、初始化本次日志，确认是 iOS 主 App 构建，并校验输出路径与构建目录隔离。

3、在系统临时目录复制 App 到 `Payload/<App名>.app`。真机保留有效签名；原签名未通过时按当前构建身份补签，再做严格校验。模拟器允许无签名快照。

4、在 `build/` 外完成压缩并检查 IPA 非空。签名、复制或压缩失败时保留原产物。

5、打包成功后清空 `../../build/`，包括隐藏文件、子目录、旧包和另一平台 IPA，写入本次唯一新包；退出时清理本脚本创建的临时快照。

**清空 build/ 不可恢复。** 必须把需保留的产物提前移出该目录。清理或写入新包阶段失败可能已经移除部分旧内容，不能把这类失败等同于压缩前失败的保留策略。

`模拟器.ipa` 仅为模拟器 App 的 Payload 快照，不能安装到真机或正式分发。`真机.ipa` 是否可安装取决于签名和描述文件；正式发布仍使用 Archive / Organizer。`clean`、非 iOS、Tests / Widget 不独立输出 IPA；测试触发主 App 重建仍可能替换产物。该阶段成功不代表后续 Scheme 动作或测试完成。

## 四、日志与常见问题 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

业务输出同步到 Xcode 构建日志 / 终端与系统临时目录中的 `save_device_ipa_after_build.log`，确认后每次覆盖。临时快照目录使用相同脚本名加随机后缀，完成或失败退出时清理。

| 现象 | 处理 |
| --- | --- |
| 双击后没有生成 IPA | 检查确认、有效 App 与环境变量；脚本不会自动编译 |
| 缺少可交互输入 | 通过交互终端或项目现有 Xcode 构建阶段运行 |
| build/ 内含构建工作路径 | 把 App、DerivedData、构建中间目录或临时目录移到 build/ 外 |
| 真机签名失败 | 在 Xcode 配置正确 Team、证书、描述文件，再重新构建 |
| 旧平台 IPA 消失 | 成功流程只保留本次平台包，重要产物应提前移出 build/ |
| 移动项目后找不到脚本 | 保持本包位于 ScriptsByDevTools 下，工程调用使用相对路径 |

## 五、验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

验证采用 `zsh -n`、工程配置与引用检查，以及隔离展示 / 取消 / 非交互退出用例。没有为迁移运行真实 `pod install`、`xcodebuild`、签名、打包或清空工程 `build/`；已有 IPA 保持原样。实际签名、安装及分发结果须以实际构建与设备验收为准。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
