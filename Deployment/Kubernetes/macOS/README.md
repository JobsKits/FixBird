# <font id=前言>[**macOS**](https://www.apple.com/macos/) · [**Kubernetes**](https://kubernetes.io/) 部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

支持 Intel（`amd64`）和 Apple Silicon（`arm64`）的 [**macOS**](https://www.apple.com/macos/)。需要 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 和 [**Minikube**](https://minikube.sigs.k8s.io/docs/)；缺失时安装固定 v1.39.0，已有健康工具复用。请查看 [Docker Desktop for Mac 安装要求](https://docs.docker.com/desktop/setup/install/mac-install/) 与 [Minikube 入门文档](https://minikube.sigs.k8s.io/docs/start/)。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在 Finder 双击 `deploy.command`。脚本按芯片下载 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 与 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 对应二进制，构建 [**Go**](https://go.dev/) API 镜像、启动本地 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 集群并应用 [**Kubernetes**](https://kubernetes.io/) 清单。安装 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 可能要求管理员授权；首次启动仍须在 [**Docker**](https://www.docker.com/) 窗口接受许可条款。

部署后保持 Terminal 窗口打开，以维持 API 的本机端口转发。后台地址为 `http://127.0.0.1:8081/admin/`。日志位于 `~/Library/Logs/RepairMarketplace/kubernetes.log`。

运行入口会先显示脚本自述，并等待按回车确认；按 Ctrl+C 可取消。

此路线复用 Docker 路线的自动代理配置：读取系统已启用的 HTTP/HTTPS 代理，显示地址与重启影响，**另行等待回车确认**后，通过 [Docker 官方安装器](https://docs.docker.com/desktop/setup/install/mac-install/#proxy-configuration) 自动应用。无需进入 Settings，端口不硬编码，可能需要管理员密码。

代理检查覆盖镜像仓库与认证端点；应用镜像的 `docker build` 设置临时客户端代理变量，覆盖本机 Buildx 的认证请求。Minikube 本机命令也使用该代理完成基础镜像、工具等下载，并绕过集群网段；本机回环代理不会作为节点内的代理使用。脚本不修改 Shell 配置，每次先检查 / 启动集群并更新本机连接配置，再导入应用和 TiDB 镜像。

脚本先检查代理与 Docker Hub 的连通性；当前 Desktop 代理配置相同时直接复用，无需重启或管理员密码。配置变化时才备份设置到 `~/Library/Logs/RepairMarketplace/docker-proxy-backup.*/settings-store.json`，再停止并重新启动 Docker Desktop。重启会中断其它容器项目及已有 Minikube 节点；代理软件需保持运行。每次检测到系统代理都会提示确认。未检测到系统 HTTP/HTTPS 代理时保留当前配置，不自动转换仅有 SOCKS 或 PAC 的配置。此步骤配置 Docker Desktop 的出口，不代表 Minikube 内全部网络问题都会解决。

自动下载使用清单固定的官方版本与架构地址，最多尝试三次。连接持续失败时，可在浏览器下载终端显示的同版本 `Docker.dmg`，再按提示拖入本地文件；直接回车取消。也可通过 `DOCKER_DESKTOP_DMG` 指定本地包。安装前必须通过清单 SHA256、DMG 完整性和 Docker 开发者签名校验；其它版本不会绕过校验。

本机 daemon 校验、显式 `minikube` profile、单节点拒绝与既有 PVC 归属确认见 [共享部署说明](../Shared/README.md)；复用确认中回车取消，输入任意字符后回车复用。`--keep-context` 保留用户当前 Kubernetes context。固定版本和下载维护见 [共享组件说明](../../Shared/README.md)。

## 三、部署边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这是 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 单节点演示集群；[**TiDB**](https://docs.pingcap.com/tidb/stable/) 使用单副本 PVC。API 已支持账号会话，管理员首次创建与私有图片持久卷见[共享说明](../Shared/README.md)。服务通过本机回环端口转发；生产运行保障仍在后续阶段。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.command`](../../../unDeployment/Kubernetes/macOS/uninstall.command)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
