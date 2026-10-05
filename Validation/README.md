# 原型统一验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

统一验证入口检查当前原型的业务、客户端和部署材料：语法、测试、临时内存 API 和模拟命令；不运行真实部署、数据库迁移、卸载、依赖安装或 App 打包。独立 HTTP 检查另提供显式的临时 TiDB 验证方式，只允许专用本机测试实例。

## 一、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先准备 [**Node.js**](https://nodejs.org) 24、[**Go**](https://go.dev/) 1.26.8、`gofmt`、`bash` 和 `zsh`；[**macOS**](https://www.apple.com/macos/) 上的源码解析需要 [**Xcode**](https://developer.apple.com/xcode) 命令行工具。在项目根目录执行：

```sh
node Validation/validate.mjs
```

Go 不在 PATH 时，可用 `GO_BINARY` 和 `GOFMT_BINARY` 指定已有工具的路径；已有便携 PowerShell 可通过 `POWERSHELL_BINARY` 指定。入口不下载工具；缺失必需工具会失败。PowerShell 不在本机时会明确跳过实际语法解析，由 Windows CI 验证。

仅验证部署材料：

```sh
node Validation/validate.mjs --scripts-only
```

`--require-powershell` 将缺少 PowerShell 视为失败；`--require-ios` 将缺少 macOS 的 Swift 解析环境视为失败。退出码非 0 表示验证失败，控制台显示失败数和跳过数；模拟脚本使用系统临时目录。

## 二、检查范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 范围 | 内容 |
| --- | --- |
| Go | 格式、单元测试、竞态检查、静态检查；测试包串行，包内并发合同仍执行；构建临时内存 API 做真实 HTTP 全流程，无需真实数据库 |
| WebAdmin | 同源、回退、超时、金额、分页、真实账号、审核、私有图片、账务与 CSV、环境／会话竞态；JavaScript 语法 |
| Web PC 入口 | 登录失败、二维码待确认／一次兑换、独立退出、会话恢复、设备撤销及旧响应隔离；JavaScript 语法 |
| iOS | `App/` 业务源码语法，金额／快照／回退、账号、资料、账务、设备与扫码业务回归；不解析第三方 Pods、不修改既有 IPA |
| 部署 / 反安装 | Shell 语法、PowerShell UTF-8 BOM / AST、临时模拟目标与保护条件 |

`parse-powershell.ps1` 只调用 [**PowerShell**](https://learn.microsoft.com/powershell/) 的 Parser，不执行待检查脚本。

`smoke-api.mjs` 始终选择临时回环端口，覆盖注册／登录、私有图片、人工审核、扫码授权、手机退出后 PC 保留会话、撤销指定设备，以及下单、并发同键重试、角色隔离、工单流转、三渠道 501、模拟收款、重复核销、平衡账本与导出。默认强制清空子进程 `TIDB_DSN`，不接受现有服务地址；退出时停止自己启动的进程并清理自己创建的临时构建目录。

专用本机 TiDB 测试实例准备好后，可以单独执行：

```sh
REPAIR_TEST_TIDB_DSN='root@tcp(127.0.0.1:测试端口)/repair_test_probe' \
  node Validation/smoke-api.mjs --tidb
```

只接受回环主机与 `repair_test_` 前缀。脚本另外创建随机测试数据库，运行全部迁移且不加载种子数据，然后执行相同的真实 HTTP 流程；结束删除自己创建的数据库。它不迁移指定名称的数据库，不连接已有 API，也不自动安装或启动数据库。不要将业务实例用于此检查。

## 三、持续集成与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`../.github/workflows/validate.yml` 提供 [**GitHub Actions**](https://docs.github.com/actions) 配置：macOS 检查业务及 Shell，Windows 使用系统 Windows PowerShell 5.1 解析入口并运行模拟回归。官方 Actions 使用其当前文档中的 v7，依据 [checkout](https://github.com/actions/checkout)、[setup-go](https://github.com/actions/setup-go) 和 [setup-node](https://github.com/actions/setup-node)；仅授予只读仓库权限，不执行部署。

当前目录尚未初始化 Git；配置文件准备好不等于远端工作流已经运行。语法与模拟测试不能代替各操作系统的真实安装验收、真机交互和 TiDB 实例测试。iOS 完整构建须使用隔离工作副本，避免 `Save Build IPA` 阶段替换既有产物。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
