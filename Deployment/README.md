# 服务器部署方案

![啄木鸟与维修扳手组合 Logo 横幅](../README-banner.svg)

[toc]

---

## 🔥 <font id=前言>前言</font>

本目录提供按操作系统和发行版选择的一键部署入口，尽量避免在主机全局安装 [**Go**](https://go.dev/)、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 或编排工具。[**Docker**](https://www.docker.com/) 与 [**Kubernetes**](https://kubernetes.io/) 是两条并行路线：本机预览优先使用 [**Docker Compose**](https://docs.docker.com/compose/)，单机编排验证可使用 [**Kubernetes**](https://kubernetes.io/)。

两条路线共用同一份 [**Go**](https://go.dev/) API 镜像和业务清单。脚本按操作系统版本与 CPU 架构选择安装流程，平台专属入口调用共享部署代码；每个入口都配有 README，说明适用系统、影响范围、访问方式与限制。目标是减少首次部署和日常维护所需的人工操作。所有平台入口启动后都会先显示脚本自述并等待回车；按 Ctrl+C 可取消，没有交互输入时会停止，不会跳过确认。

## 一、目录结构 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
./
├── Docker/                    # Docker Engine / Docker Desktop + Docker Compose
│   ├── Linux/<发行版>/         # 每个发行版独立 deploy.sh 与 README.md
│   ├── macOS/                  # Finder 双击入口 deploy.command
│   ├── Windows/                # Windows PowerShell 入口 deploy.ps1
│   └── Shared/                 # 镜像、Compose 清单和平台公共函数
├── Kubernetes/                # K3s / Minikube 单节点 Kubernetes
│   ├── Linux/<发行版>/         # 每个发行版独立 deploy.sh 与 README.md
│   ├── macOS/                  # Finder 双击入口 deploy.command
│   ├── Windows/                # Windows PowerShell 入口 deploy.ps1
│   └── Shared/                 # Kubernetes 工作负载与平台公共函数
├── Shared/                    # 固定组件版本、官方 URL / SHA256、本机目标校验
└── Tests/                     # 函数替身与编码 / Parser 检查，无真实部署操作
```

## 二、部署路线 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 路线 | [**Linux**](https://www.kernel.org/) | [**macOS**](https://www.apple.com/macos/) | [**Windows**](https://www.microsoft.com/windows) | 用途 |
| --- | --- | --- | --- | --- |
| [**Docker**](https://www.docker.com/) | [**Docker Engine**](https://docs.docker.com/engine/) + [**Docker Compose**](https://docs.docker.com/compose/) | [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) + [**Docker Compose**](https://docs.docker.com/compose/) | [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) + [**Docker Compose**](https://docs.docker.com/compose/) | 当前推荐的低开销本机预览与单机运行 |
| [**Kubernetes**](https://kubernetes.io/) | [**Docker Engine**](https://docs.docker.com/engine/) + [**K3s**](https://docs.k3s.io/) | [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) + [**Minikube**](https://minikube.sigs.k8s.io/docs/) | [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) + [**Minikube**](https://minikube.sigs.k8s.io/docs/) | 验证清单、滚动更新与后续编排迁移 |

选择与你当前系统相符的 `deploy.sh`、`deploy.command` 或 `deploy.ps1`。[**Linux**](https://www.kernel.org/) 脚本会检测 `/etc/os-release` 和 `uname -m`，不匹配时会停止；[**Docker**](https://www.docker.com/) 镜像支持 `x86_64` / `aarch64`。每个入口会准备容器运行环境、构建或下载镜像、部署 API 和 [**TiDB**](https://docs.pingcap.com/tidb/stable/)，并检查 API 健康状态。

### 2.1、单机与集群的选型 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Docker Compose**](https://docs.docker.com/compose/) 适合在一台主机上定义和启动多个关联服务，例如本项目的 API 与数据库。[**Kubernetes**](https://kubernetes.io/) 提供集群级容器编排，可统一管理服务调度、滚动更新、故障恢复和扩缩容；实际扩缩容仍需配置相应策略与资源。

| 场景 | 优先考虑 | 选择依据 |
| --- | --- | --- |
| 本机预览、开发联调 | Docker Compose | 组件少，启动和排查直接，维护成本较低 |
| 单台服务器、少量服务 | Docker Compose | 适合单机部署，通常无需承担集群管理复杂度 |
| 单台服务器上的编排学习或环境一致性验证 | Kubernetes 单节点集群 | 可验证清单和滚动更新，但需要额外维护集群组件 |
| 多台服务器、跨节点调度与服务扩展 | Kubernetes 多节点集群 | 可将工作负载分配到不同节点，并根据可用资源重新调度 |

单台服务器也能运行 Kubernetes。单节点集群能够重建异常容器，但整台主机故障时没有其它节点承接服务；多节点集群也需要可用容量、健康的控制面及合适的存储配置，才能实现预期的故障恢复。应用副本恢复与数据库数据恢复需要分别设计。

本项目当前以本机预览和单机原型为主，优先使用 Docker Compose；需要验证编排能力或规划多节点部署时，再使用 Kubernetes 路线。业务增长应先根据 API / 数据库容量和可用性要求选择扩容方式，不意味着必须替换为 Kubernetes。当前脚本只处理单节点演示环境，已有多节点集群会拒绝，多节点与生产高可用配置需另外建设。

Docker 命名卷和 Kubernetes PVC 保存不同实例的数据，切换路线不会自动迁移。切换前应冻结写入、另做可验证的数据库逻辑备份，导入目标实例并校验迁移版本、订单和资金演示数据，再验收和切换访问地址；`unDeployment` 的全环境冷归档用于同平台兼容环境恢复，不是跨路线或跨系统的数据迁移工具。

### 2.2、Kubernetes 与 Docker 的依赖关系 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Kubernetes 本身不要求安装 Docker Engine 或 Docker Desktop。节点需要符合 CRI 接口的容器运行时，例如 [**containerd**](https://containerd.io/) 或 [**CRI-O**](https://cri-o.io/)；具体支持方式见 [Kubernetes 容器运行时说明](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)。容器镜像的构建工具与节点的容器运行时也可以分别选择。

本项目维护两条部署路线，但当前实现共用部分底层工具：

| 路线与平台 | 当前执行关系 | Docker 的职责 |
| --- | --- | --- |
| Docker 路线 | Docker Engine / Docker Desktop → Compose → API、TiDB | 构建并运行应用容器 |
| Kubernetes · macOS / Windows | Docker Desktop → Minikube Docker 驱动 → Kubernetes → API、TiDB | 承载 Minikube 节点，并通过 `docker build` 构建应用镜像 |
| Kubernetes · Linux | Docker Engine 构建镜像 → 导入 K3s → Kubernetes → API、TiDB | 作为镜像构建工具；K3s 使用自带的 containerd 运行工作负载 |

因此，当前 Kubernetes 桌面入口安装 Docker Desktop，是脚本选择了 `minikube start --driver=docker`，并使用 `docker build`。这是本项目的实现选择，不能据此推断所有 Kubernetes 环境都依赖 Docker。

如需让两条路线的运行环境完全独立，桌面 Kubernetes 路线需要选择适配系统与芯片的虚拟机驱动，并配套独立的镜像构建流程；Linux 路线也需要替换现有 Docker 镜像构建步骤。[Minikube 官方说明](https://minikube.sigs.k8s.io/docs/tutorials/docker_desktop_replacement/) 提供了使用虚拟机驱动替代 Docker Desktop 的思路；本项目当前入口尚未采用该方案。

### 2.3、一键部署的覆盖范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

一键入口负责串联环境准备、镜像构建和服务启动。首次运行仍可能需要联网、管理员授权及手动接受 Docker Desktop 许可；入口先显示自述，按回车确认后执行。运行条件详见 [首次运行条件与系统边界](#五首次运行条件与系统边界)。

Docker 路线以后台容器运行服务，部署成功后可以关闭入口终端；Docker 引擎仍须保持运行。Kubernetes 路线通过前台端口转发提供本机访问，需保持入口终端打开，关闭终端会结束转发。脚本不保证电脑重启后自动恢复完整访问链路。

数据库持久化卷用于保存数据，一键部署没有提供自动备份或生产级高可用。鉴权、TLS、备份恢复及集群容量等要求见 [演示环境与生产环境边界](#六演示环境与生产环境边界)。

## 三、[**Linux**](https://www.kernel.org/) 镜像支持范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

每种发行版在 [**Docker**](https://www.docker.com/) 和 [**Kubernetes**](https://kubernetes.io/) 路线下各有独立脚本。支持范围按 [**华为云**](https://support.huaweicloud.com/productdesc-ims/ims-productdesc-pdf.pdf)、[**腾讯云**](https://cloud.tencent.com/document/product/213/93093) 与 [**阿里云**](https://help.aliyun.com/zh/ecs/user-guide/public-mirroring-overview) 公共镜像中常见且仍有维护价值的版本收敛；脚本会根据 `/etc/os-release` 的 `ID`、`VERSION_ID` 自动识别。

| 发行版 | [**Docker**](https://www.docker.com/) / [**Kubernetes**](https://kubernetes.io/) 入口目录 | 支持版本 |
| --- | --- | --- |
| [**Alibaba Cloud Linux**](https://www.alibabacloud.com/help/en/alinux/product-overview/alibaba-cloud-linux-overview) | `Docker/Linux/Alibaba-Cloud-Linux/` 与 `Kubernetes/Linux/Alibaba-Cloud-Linux/` | 3、4 |
| [**AlmaLinux**](https://almalinux.org/) | `Docker/Linux/AlmaLinux/` 与 `Kubernetes/Linux/AlmaLinux/` | 8、9、10 |
| [**Amazon Linux**](https://aws.amazon.com/linux/amazon-linux-2023/) | `Docker/Linux/Amazon-Linux-2023/` 与 `Kubernetes/Linux/Amazon-Linux-2023/` | 2023 |
| [**Anolis OS**](https://openanolis.cn/) | `Docker/Linux/Anolis-OS/` 与 `Kubernetes/Linux/Anolis-OS/` | 8、23 |
| [**CentOS Stream**](https://www.centos.org/centos-stream/) | `Docker/Linux/CentOS-Stream/` 与 `Kubernetes/Linux/CentOS-Stream/` | 9、10 |
| [**Debian**](https://www.debian.org/) | `Docker/Linux/Debian/` 与 `Kubernetes/Linux/Debian/` | 12、13 |
| [**Fedora Linux**](https://fedoraproject.org/) | `Docker/Linux/Fedora/` 与 `Kubernetes/Linux/Fedora/` | 43、44 |
| [**Huawei Cloud EulerOS**](https://support.huaweicloud.com/productdesc-hce/hce_01_0001.html) | `Docker/Linux/Huawei-Cloud-EulerOS/` 与 `Kubernetes/Linux/Huawei-Cloud-EulerOS/` | 2.0 |
| [**OpenCloudOS**](https://opencloudos.org/) | `Docker/Linux/OpenCloudOS/` 与 `Kubernetes/Linux/OpenCloudOS/` | 8、9 |
| [**Oracle Linux**](https://www.oracle.com/linux/) | `Docker/Linux/Oracle-Linux/` 与 `Kubernetes/Linux/Oracle-Linux/` | 8、9、10 |
| [**Red Hat Enterprise Linux**](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux) | `Docker/Linux/RHEL/` 与 `Kubernetes/Linux/RHEL/` | 8、9、10 |
| [**Rocky Linux**](https://rockylinux.org/) | `Docker/Linux/Rocky-Linux/` 与 `Kubernetes/Linux/Rocky-Linux/` | 8、9、10 |
| [**SUSE Linux Enterprise Server**](https://www.suse.com/products/server/) | `Docker/Linux/SUSE-Linux-Enterprise-Server/` 与 `Kubernetes/Linux/SUSE-Linux-Enterprise-Server/` | 15 SP7 |
| [**TencentOS Server**](https://cloud.tencent.com/document/product/1397/72787) | `Docker/Linux/TencentOS-Server/` 与 `Kubernetes/Linux/TencentOS-Server/` | 3.3、4.0 |
| [**Ubuntu**](https://ubuntu.com/) | `Docker/Linux/Ubuntu/` 与 `Kubernetes/Linux/Ubuntu/` | 20.04 LTS（需 Pro/ESM）、22.04、24.04、26.04 LTS |
| [**openEuler**](https://www.openeuler.org/) | `Docker/Linux/openEuler/` 与 `Kubernetes/Linux/openEuler/` | 20.03、22.03、24.03 LTS |
| [**openSUSE Leap**](https://get.opensuse.org/leap/) | `Docker/Linux/openSUSE-Leap/` 与 `Kubernetes/Linux/openSUSE-Leap/` | 16.0 |

[**CentOS Linux**](https://www.centos.org/centos-linux/) 7/8、[**Amazon Linux**](https://aws.amazon.com/linux/amazon-linux-2023/) 2、[**Alibaba Cloud Linux**](https://www.alibabacloud.com/help/en/alinux/product-overview/alibaba-cloud-linux-overview) 2 等已结束维护的版本不纳入默认支持；[**CentOS Linux**](https://www.centos.org/centos-linux/) 用户应迁移至 [**CentOS Stream**](https://www.centos.org/centos-stream/)、[**TencentOS Server**](https://cloud.tencent.com/document/product/1397/72787)、[**OpenCloudOS**](https://opencloudos.org/) 或兼容发行版。不可变系统（如 [**Fedora CoreOS**](https://fedoraproject.org/coreos/) / [**Flatcar**](https://www.flatcar.org/)）和未列出的发行版不走此安装器。

[**Ubuntu**](https://ubuntu.com/) 20.04 标准维护期已结束，仅在启用 [**Ubuntu Pro / ESM**](https://ubuntu.com/security/esm) 后纳入入口；[**Fedora**](https://fedoraproject.org/wiki/Fedora_Release_Life_Cycle) 仅接收当前受维护版本；[**openSUSE Leap**](https://get.opensuse.org/leap/) 15.x 已结束维护，默认只接收 Leap 16.0。镜像清单会随云厂商和上游生命周期变化，筛选依据见 [**阿里云公共镜像**](https://help.aliyun.com/zh/ecs/user-guide/public-mirroring-overview)、[**腾讯云公共镜像**](https://cloud.tencent.com/document/product/213/93093) 与 [**华为云支持的操作系统**](https://support.huaweicloud.com/productdesc-ims/ims-productdesc-pdf.pdf)。[**Docker Engine**](https://docs.docker.com/engine/install/) 上游正式验证范围少于本项目提供的云镜像入口；衍生系统可能需要厂商仓库包，脚本无法替代云厂商对特定镜像的兼容承诺。

## 四、一键部署流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

1、检测操作系统版本和 CPU 架构，下载匹配架构的运行时或工具。

2、在需要时安装 [**Docker Engine**](https://docs.docker.com/engine/) / [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)；[**Kubernetes**](https://kubernetes.io/) 路线另外准备 [**K3s**](https://docs.k3s.io/) 或 [**Minikube**](https://minikube.sigs.k8s.io/docs/)。

3、在容器内编译 [**Go**](https://go.dev/) API，不在主机全局安装 [**Go**](https://go.dev/) SDK。

4、启动 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 单机演示实例并自动创建数据库、执行 SQL 初始化，再启动 [**Go**](https://go.dev/) API 和 [**Web**](https://developer.mozilla.org/en-US/docs/Web) 管理后台。

5、以 `/readyz` 检查数据库和迁移就绪，成功后显示并打开管理后台地址；`/healthz` 仅用于进程存活检查。

### 4.1、默认地址 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Docker**](https://www.docker.com/)：`http://127.0.0.1:8080/admin/`；健康检查 `http://127.0.0.1:8080/healthz`。

- [**Kubernetes**](https://kubernetes.io/)：本机 `http://127.0.0.1:8081/admin/`；保持部署终端运行以维持端口转发。通过 `KUBERNETES_API_PORT` 可指定其它端口，容器和 Service 内部仍使用 `8080`。

- [**Docker**](https://www.docker.com/) 默认仅监听本机；[**TiDB**](https://docs.pingcap.com/tidb/stable/) 端口 `4000` 也仅绑定本机。[**Kubernetes**](https://kubernetes.io/) 的 API 通过本机端口转发，不创建公网 Service 或 Ingress。

### 4.2、运行日志与配置 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Docker**](https://www.docker.com/) 配置：`Docker/Shared/.env`，首次运行从 `.env.example` 复制，后续不会覆盖。

- [**Docker**](https://www.docker.com/) [**Linux**](https://www.kernel.org/) 日志：当前用户状态目录中的 `repair-platform-docker.log`。

- [**Docker**](https://www.docker.com/) [**Windows**](https://www.microsoft.com/windows) 日志：当前用户本地应用数据目录中的 `RepairMarketplace/Logs/docker-deployment.log`。

- [**Docker**](https://www.docker.com/) [**macOS**](https://www.apple.com/macos/) 日志：用户 Library 日志目录中的 `RepairMarketplace/docker-deployment.log`。

- [**Kubernetes**](https://kubernetes.io/) [**Linux**](https://www.kernel.org/) 日志：当前用户状态目录中的 `repair-platform-kubernetes.log`；[**K3s**](https://docs.k3s.io/) 服务可通过 `journalctl -u k3s` 查询。

- [**Kubernetes**](https://kubernetes.io/) [**macOS**](https://www.apple.com/macos/) / [**Windows**](https://www.microsoft.com/windows) 日志：对应系统的用户日志目录中的 `kubernetes-deployment.log` 或 `kubernetes.log`。

## 五、首次运行条件与系统边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [**Linux**](https://www.kernel.org/) 安装系统包、启用服务需要 root 或可用的 `sudo`；脚本会在终端请求密码。

- [**macOS**](https://www.apple.com/macos/) 首次安装 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 时可能要求系统管理员授权，并须在 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 窗口接受许可条款；脚本不会代替用户接受许可。

- [**Windows**](https://www.microsoft.com/windows) 使用 [**PowerShell**](https://learn.microsoft.com/powershell/) `.ps1` 脚本，不会生成 CMD/BAT 包装器。[**Windows**](https://www.microsoft.com/windows) 对 `.ps1` 的默认双击行为可能是用编辑器打开；请右键选择“使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行”，或在 [**PowerShell**](https://learn.microsoft.com/powershell/) 中运行对应文件。[**Windows**](https://www.microsoft.com/windows) 10/11 客户端需有受支持的 [**WSL 2**](https://learn.microsoft.com/windows/wsl/)、虚拟化能力与 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 条件；安装 WSL 可能要求 UAC 授权或重启。[**Windows**](https://www.microsoft.com/windows) Server 不属于 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 这条自动路线。

- [**Windows**](https://www.microsoft.com/windows) ARM64 的 [**Docker**](https://www.docker.com/) 路线使用 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) ARM 构建；当前固定的 [**Minikube**](https://minikube.sigs.k8s.io/docs/) v1.39.0 [**Windows**](https://www.microsoft.com/windows) 发布物只有 AMD64，因此 [**Kubernetes**](https://kubernetes.io/) [**Windows**](https://www.microsoft.com/windows) 脚本会在安装前明确停止 ARM64。

- [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 的系统要求、发行版支持范围和许可条款会变化。运行前请核对 [macOS 安装要求](https://docs.docker.com/desktop/setup/install/mac-install/) 与 [Windows 安装要求](https://docs.docker.com/desktop/setup/install/windows-install/)。[**Linux**](https://www.kernel.org/) 系统安装依赖 [**Docker Engine**](https://docs.docker.com/engine/) 官方发行版说明；便捷安装脚本仅用于开发/测试场景。

- 初次部署需要联网下载 [**Docker**](https://www.docker.com/)、[**Go**](https://go.dev/) 基础镜像、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 镜像，以及 [**Kubernetes**](https://kubernetes.io/) 路线使用的 [**K3s**](https://docs.k3s.io/) / [**Minikube**](https://minikube.sigs.k8s.io/docs/)。没有网络或镜像源不可达时，脚本会失败并留下诊断日志，不会自动伪装成离线部署成功。

### 5.1、镜像认证与下载超时排查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

构建日志中的 `failed to fetch oauth token`、`auth.docker.io` 或 `registry-1.docker.io` 连接超时，表示构建引擎无法完成镜像仓库认证或访问；这类超时本身不能证明 Dockerfile 或登录凭据有误。已拉取某个镜像，也不代表其它镜像的认证和下载链路都可用。

macOS 的 Docker 和 Kubernetes 部署入口会读取系统已启用的 HTTP/HTTPS 代理，显示实际地址及重启影响，等待回车确认后自动配置 Docker Desktop。确认后先检查代理连通性，再备份设置、通过 [官方安装器代理参数](https://docs.docker.com/desktop/setup/install/mac-install/#proxy-configuration) 应用配置并重新启动 Docker Desktop；可能需要管理员密码。无需手动进入 Settings，代理端口不硬编码。重启会中断其它容器项目，代理软件需要保持运行。备份位于 `~/Library/Logs/RepairMarketplace/docker-proxy-backup.*`。

未检测到系统 HTTP/HTTPS 代理时保留 Docker Desktop 当前配置；仅有 SOCKS 或 PAC 时不会自动转换。代理不是部署的必需条件，能直连镜像仓库的网络无需代理。终端代理与 Docker 构建引擎的出口可能不同；其它系统的配置方式见 [Docker Desktop 代理说明](https://docs.docker.com/desktop/settings-and-maintenance/settings/)。

同时检查 DNS 是否正确解析仓库与认证域名，以及代理、防火墙是否允许这些地址。官方域名列表见 [Docker Desktop 网络允许列表](https://docs.docker.com/desktop/enterprise/allow-list/)。仅关闭 IPv6 不一定能修复 IPv4 同样不可达的网络；不要把临时解析到的仓库 IP 固定写入 `hosts`。

macOS 脚本会同时检查镜像仓库和认证端点，并为 Docker 构建命令设置临时客户端代理变量。Desktop 后台代理与本机 Buildx 认证请求属于不同执行环节；仅配置 Desktop 后仍可能出现认证超时，见 [Buildx 官方仓库问题记录](https://github.com/docker/buildx/issues/1979)。临时变量只作用于脚本中的 Docker 命令，不写入 Shell 配置文件。

代理模式、地址及绕过列表与当前 Desktop 设置相同时直接复用，配置变化时才备份并重启，避免重复部署要求管理员密码；仍保留运行时回车确认。

## 六、演示环境与生产环境边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

这套配置用于本机预览和单机原型部署。[**TiDB**](https://docs.pingcap.com/tidb/stable/) 使用单机 `unistore` 演示模式（详见 [**TiDB** 配置文档](https://docs.pingcap.com/tidb/stable/command-line-flags-for-tidb-configuration/)）；[**Kubernetes**](https://kubernetes.io/) 使用单节点集群和本地持久卷，尚未配置备份、故障转移、Ingress、TLS、监控或自动扩缩容。当前已支持账号与独立设备会话；后台、审核、私有图片和账务要求鉴权，匿名演示身份只操作演示订单。支付渠道仍未接入。真实运营前的 HTTPS、细分权限、支付回调、密钥管理、数据库运行保障和审计待后续阶段落实。

管理员首次创建、会话有效期与私有图片持久卷配置分别见 [Docker 共享说明](Docker/Shared/README.md)和 [Kubernetes 共享说明](Kubernetes/Shared/README.md)。各平台入口每次都重新构建当前源码并部署／迁移；默认主管理员由程序自动创建，不必手动补充管理员变量。代码文件修改后需要再次运行部署入口，才会更新正在运行的服务。

## 七、部署入口与组件说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- [Docker 路线](Docker/README.md)：[**Docker Engine**](https://docs.docker.com/engine/) / [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)、[**Docker Compose**](https://docs.docker.com/compose/)、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 与 API 容器。

- [Kubernetes 路线](Kubernetes/README.md)：[**Linux**](https://www.kernel.org/) [**K3s**](https://docs.k3s.io/)、桌面 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 和共享工作负载。

- 每个发行版、[**macOS**](https://www.apple.com/macos/) 与 [**Windows**](https://www.microsoft.com/windows) 入口目录都有自己的 `README.md`；公共函数与容器清单目录也分别提供 README。

- [共享版本与校验](Shared/README.md)：缺失组件的固定版本、官方 URL / SHA256 与签名校验；已有健康组件复用，不自动升级。标准本机目标校验拒绝远端 daemon / builder，后续命令显式固定端点，不切换用户全局 context。

- [隔离检查](Tests/README.md)：验证目标与数据保护门禁，不执行安装、部署或卸载。Windows PS1 统一 UTF-8 BOM，兼容默认 PowerShell 5.1；Windows CI 使用其实际 Parser 核验。

## 八、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入同级的 [`unDeployment`](../unDeployment/README.md) 选择对应系统入口，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../unDeployment/README.md)。

## 九、跨平台检查与验证范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

2026-10-05，以已跑通的 Docker/macOS 为基准检查两条路线的 38 个平台入口及共享组件。两条路线共用包含 `go.mod` / `go.sum` 的镜像构建流程；已修复 Linux 函数库漏载、下载重试 / 插件补齐、客户端代理、Minikube 连接恢复及主机端口冲突。

| 范围 | 已验证 | 尚未验证 |
| --- | --- | --- |
| Docker · macOS ARM64 | 实际部署、数据库初始化、健康检查与后台 HTTP 200 | Intel 实机 |
| Kubernetes · macOS ARM64 | Minikube 启动、镜像导入、工作负载就绪、PVC Bound、8081 健康检查与后台 HTTP 200 | Intel 实机；节点任意公网镜像下载 |
| Docker / Kubernetes · Linux | 34 个入口路径 / 函数加载；102 组支持版本、错误发行版与不支持版本检查；Shell 语法 | 各发行版的真实软件安装、systemd、权限、网络与 K3s 实际部署 |
| Docker / Kubernetes · Windows | 4 个 PS1 语法解析；原生架构、中文 WSL 版本、代理环境恢复及退出码模拟检查 | Windows 实机上的安装、UAC / WSL、Desktop 后台代理与 Minikube 部署 |

上表是此前原型的实跑/矩阵记录。本次修复没有重启 Docker、重跑部署或执行卸载；新增隔离测试验证本机目标、K3s 单节点归属、live-restore/writer 拒绝、Buildx 安装所有权和下载摘要，并检查全部部署/反部署 PS1 的 BOM / Parser。PowerShell 本机检查使用官方 macOS ARM64 临时运行包，Windows 5.1 Parser 另由 Windows CI / 实机验证，不能据此宣称 Windows 安装已通过。Kubernetes 端口转发需保持运行；停止转发后集群工作负载仍存在。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
