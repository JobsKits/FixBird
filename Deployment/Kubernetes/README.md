# <font id=前言>[**Kubernetes**](https://kubernetes.io/) 部署路线</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

[**Kubernetes**](https://kubernetes.io/) 与 [**Docker**](https://www.docker.com/) 路线并列维护，共用同一个 [**Go**](https://go.dev/) API 镜像和 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 工作负载描述。此版本用于本地/单机验证编排；不代表已经具备生产高可用能力。

## 一、平台入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Linux**](https://www.kernel.org/)：每个受支持发行版都有独立的 [`Linux/<发行版>/deploy.sh`](Linux/) 和 README。脚本安装 [**Docker**](https://www.docker.com/) 镜像构建工具与 [**K3s**](https://docs.k3s.io/) 单节点集群。
- [**macOS**](https://www.apple.com/macos/)：Finder 双击 [`macOS/deploy.command`](macOS/deploy.command)，[**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 为 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 驱动。
- [**Windows**](https://www.microsoft.com/windows)：[**PowerShell**](https://learn.microsoft.com/powershell/) 运行 [`Windows/deploy.ps1`](Windows/deploy.ps1)，[**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 为 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 驱动。

所有平台入口启动后都会先显示脚本自述并等待回车确认；按 Ctrl+C 可取消，没有交互输入时会停止。

## 二、部署流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

平台入口检测版本和 CPU 架构，准备本地镜像构建环境、构建 `repair-marketplace-api:local`、将镜像导入本地 [**Kubernetes**](https://kubernetes.io/)，再应用 [`Shared/workloads.yaml`](Shared/workloads.yaml)。清单部署 [**TiDB**](https://docs.pingcap.com/tidb/stable/) StatefulSet、内部 Service 和 [**Go**](https://go.dev/) API Deployment。启动后会通过本机回环端口转发提供 `http://127.0.0.1:8081/admin/`；需要保持脚本打开的终端以维持转发。

[**Linux**](https://www.kernel.org/) 使用宿主机 [**K3s**](https://docs.k3s.io/) 服务和持久卷。[**macOS**](https://www.apple.com/macos/) / [**Windows**](https://www.microsoft.com/windows) 使用 [**Minikube**](https://minikube.sigs.k8s.io/docs/) [**Docker**](https://www.docker.com/) 驱动；[**Minikube**](https://minikube.sigs.k8s.io/docs/) 固定版本为 v1.39.0。其官方 [**Windows**](https://www.microsoft.com/windows) 二进制目前仅提供 AMD64，因此 [**Windows**](https://www.microsoft.com/windows) ARM64 脚本会预检并退出；[**Windows**](https://www.microsoft.com/windows) ARM64 用户可运行 [**Docker**](https://www.docker.com/) 路线。

## 三、数据与限制 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**TiDB**](https://docs.pingcap.com/tidb/stable/) 使用单副本、5 GiB 本地 PVC 和 `unistore` 演示配置。API 默认无认证，Service 为 ClusterIP；脚本不创建公网入口、Ingress 或 TLS。此方案适合熟悉 YAML 和观察容器编排，不提供生产级数据库备份、集群高可用或自动扩缩容。

[**Kubernetes**](https://kubernetes.io/) [**Linux**](https://www.kernel.org/) 部署会安装并启用主机 [**Docker Engine**](https://docs.docker.com/engine/) 作为镜像构建工具，同时安装 [**K3s**](https://docs.k3s.io/)；运行时 [**Kubernetes**](https://kubernetes.io/) 节点由 [**K3s**](https://docs.k3s.io/) 自带的 containerd 管理。 [**macOS**](https://www.apple.com/macos/) / [**Windows**](https://www.microsoft.com/windows) 则使用 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 与 [**Minikube**](https://minikube.sigs.k8s.io/docs/)。

## 四、组件说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [Shared/README.md](Shared/README.md)：工作负载清单与端口转发。
- [macOS/README.md](macOS/README.md)：[**Minikube**](https://minikube.sigs.k8s.io/docs/) 安装与端口转发。
- [Windows/README.md](Windows/README.md)：[**Minikube**](https://minikube.sigs.k8s.io/docs/)、[**WSL 2**](https://learn.microsoft.com/windows/wsl/) 和架构限制。

## 五、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入同级的 [`unDeployment`](../../unDeployment/README.md) 选择对应系统入口，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
