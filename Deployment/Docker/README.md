# <font id=前言>[**Docker**](https://www.docker.com/) 部署路线</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

[**Docker**](https://www.docker.com/) 是当前的默认预览路线，使用 [**Docker Engine**](https://docs.docker.com/engine/) / [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 与 [**Docker Compose**](https://docs.docker.com/compose/) 启动 [**Go**](https://go.dev/) API 和 [**TiDB**](https://docs.pingcap.com/tidb/stable/)。容器构建阶段固定使用 [**Go**](https://go.dev/) 1.26.8；主机无需安装 [**Go**](https://go.dev/) SDK 或 [**TiDB**](https://docs.pingcap.com/tidb/stable/)。

## 一、平台入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Linux**](https://www.kernel.org/)：从 [`Linux/`](Linux/) 进入与你的发行版对应的文件夹。每个文件夹中的 `deploy.sh` 会识别系统版本与 CPU 架构。
- [**macOS**](https://www.apple.com/macos/)：Finder 双击 [`macOS/deploy.command`](macOS/deploy.command)。
- [**Windows**](https://www.microsoft.com/windows)：使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行 [`Windows/deploy.ps1`](Windows/deploy.ps1)。[**Windows**](https://www.microsoft.com/windows) PS1 默认不保证普通双击执行，见入口 README。

所有平台入口启动后都会先显示脚本自述并等待回车确认；按 Ctrl+C 可取消，没有交互输入时会停止。

## 二、部署内容 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

`Shared/compose.yaml` 使用固定项目名 `repair-marketplace`，部署 [**TiDB**](https://docs.pingcap.com/tidb/stable/) v8.5.8 和本地构建的 [**Go**](https://go.dev/) API。容器启动时等待 [**TiDB**](https://docs.pingcap.com/tidb/stable/)，自动创建数据库并执行 `Server/migrations/001_init.sql`，之后启动 API；后台由 [**Go**](https://go.dev/) 服务同源提供。

各平台入口每次先构建当前源码，再部署容器并用 `/readyz` 验收。默认管理后台 `http://127.0.0.1:8080/admin/`，先展示登录页，首次自动创建 `admin / admin`；管理员在设置中管理账号与权限。已配置的局域网地址会自动保留，数据库与图片数据卷保留。健康检查 `/healthz`。配置位于 `Shared/.env`，日志路径和首次安装约束见各平台 README。

## 三、数据与限制 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**TiDB**](https://docs.pingcap.com/tidb/stable/) 数据写入 [**Docker**](https://www.docker.com/) 命名卷。删除容器不会主动删除卷；要查看/备份数据请使用 [**Docker**](https://www.docker.com/) 卷管理工具。[**TiDB**](https://docs.pingcap.com/tidb/stable/) `unistore` 单节点配置仅供演示，不等同于生产 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 集群。默认 API 与数据库端口仅绑定本机，演示 API 无认证，禁止公网暴露。

[**Linux**](https://www.kernel.org/) 安装脚本会优先尝试 [**Docker**](https://www.docker.com/) 官方便捷安装流程，失败后按系统软件仓库回退；[**Docker**](https://www.docker.com/) 官方将便捷安装流程定位于开发和测试用途。不同云厂商衍生发行版的 [**Docker**](https://www.docker.com/) CE 兼容性需按各入口 README 说明判断。

## 四、组件说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [Shared/README.md](Shared/README.md)：镜像、Compose、配置与共享安装函数。
- [macOS/README.md](macOS/README.md)：Apple 芯片 / Intel 安装方式。
- [Windows/README.md](Windows/README.md)：[**Windows**](https://www.microsoft.com/windows) 客户端与 [**WSL 2**](https://learn.microsoft.com/windows/wsl/) 条件。

## 五、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入同级的 [`unDeployment`](../../unDeployment/README.md) 选择对应系统入口，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
