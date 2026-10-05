# <font id=前言>[**macOS**](https://www.apple.com/macos/) · [**Docker**](https://www.docker.com/) 部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

支持 Intel（`amd64`）和 Apple Silicon（`arm64`）的 [**macOS**](https://www.apple.com/macos/)。[**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 对 [**macOS**](https://www.apple.com/macos/) 版本、内存和许可的要求会变化，请在运行前查看 [Docker Desktop for Mac 安装要求](https://docs.docker.com/desktop/setup/install/mac-install/)。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在 Finder 双击 `deploy.command`。Terminal 会按芯片下载匹配架构的 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)；需要时会出现管理员授权提示。首次启动 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 还需在应用窗口接受其许可条款，脚本不会代替用户接受许可。

运行入口会先显示脚本自述，并等待按回车确认；按 Ctrl+C 可取消。

检测到系统已启用的 HTTP/HTTPS 代理时，脚本会显示代理地址、绕过列表和重启影响，**再次等待回车确认**，然后通过 [Docker 官方安装器代理参数](https://docs.docker.com/desktop/setup/install/mac-install/#proxy-configuration) 自动配置。无需手动进入 Settings。地址随系统设置读取，不固定为某个端口；仅设置一个协议代理时，另一协议复用该地址。可能需要管理员密码。

代理检查同时覆盖镜像仓库和 `auth.docker.io` 认证端点。后续 Compose 命令会通过临时的 `HTTP_PROXY` / `HTTPS_PROXY` 及对应小写变量，让本机 Buildx 客户端的认证请求也走代理；仅配置 Desktop 代理可能漏掉这段请求，见 [Buildx 官方仓库问题记录](https://github.com/docker/buildx/issues/1979)。临时变量只作用于 Docker 命令，不写入 Shell 配置文件，也不传给其它工具。

确认后先检查代理能否连接 Docker Hub。当前 Desktop 代理配置相同时直接复用，无需重启或管理员密码；配置变化时才备份设置、停止并重新启动 Docker Desktop，再继续部署。重启会中断其它容器项目；代理软件需要保持运行。原设置保存在 `~/Library/Logs/RepairMarketplace/docker-proxy-backup.*/settings-store.json`，仅在 Docker Desktop 停止时恢复备份。每次检测到系统代理都会重新提示确认。没有系统 HTTP/HTTPS 代理时保留当前配置；仅有 SOCKS 或 PAC 配置时不会自动转换。

自动下载使用清单固定的官方版本与架构地址，最多尝试三次。连接持续失败时，可在浏览器下载终端显示的同版本 `Docker.dmg`，再按提示拖入本地文件；直接回车取消。也可通过 `DOCKER_DESKTOP_DMG` 指定本地包。安装前必须通过清单 SHA256、DMG 完整性和 Docker 开发者签名校验；其它版本不会绕过校验。

脚本拒绝远端或非标准 Docker context，后续命令固定到已确认的本机 socket，不切换全局 context；Apple Silicon 在 Rosetta 环境也按硬件 ARM64 下载。固定版本、下载维护方法见 [共享组件说明](../../Shared/README.md)。

## 三、部署内容 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

脚本按需准备 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)，复制默认 `.env` 配置，每次重新构建当前源码的 [**Go**](https://go.dev/) API 镜像并用 Compose 更新或启动 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 与后台服务。[**Go**](https://go.dev/) SDK 不安装到主机。成功后自动打开 `http://127.0.0.1:8080/admin/` 登录页。程序首次自动创建 `admin / admin`，账号权限在后台“设置”管理。已配置的局域网网卡地址自动保留；数据库与私有图片数据卷保留。

默认 API 与 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 端口只绑定本机回环地址。数据位于 [**Docker**](https://www.docker.com/) 命名卷。日志位于 用户 Library 日志目录中的 `RepairMarketplace/docker-deployment.log`。这是无鉴权的单机演示，不应直接暴露到公网。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.command`](../../../unDeployment/Docker/macOS/uninstall.command)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
