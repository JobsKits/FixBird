# <font id=前言>[**Kubernetes**](https://kubernetes.io/) Shared 部署组件</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

此目录保存 [**Kubernetes**](https://kubernetes.io/) 路线共用的工作负载清单及各平台控制面安装函数。

## 一、文件用途 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `workloads.yaml`：部署 `repair-marketplace` Namespace、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 单副本 StatefulSet / PVC、内部 Service 与 API Deployment。
- `deploy-linux.sh`：通过匹配发行版入口安装 [**K3s**](https://docs.k3s.io/)，构建并导入 API 镜像，应用清单并运行本机 `kubectl port-forward`。
- `macos-deploy.zsh`：为 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 安装架构匹配的 [**macOS**](https://www.apple.com/macos/) 二进制，构建镜像、应用清单并转发端口。
- `deploy-windows.ps1`：复用 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 安装函数、按 AMD64 安装 [**Minikube**](https://minikube.sigs.k8s.io/docs/)，部署清单并维持端口转发。

平台部署入口会先打印自述并等待回车确认；按 Ctrl+C 可取消，没有交互输入时会退出。

主机转发端口默认 `8081`，与 Docker 路线的 `8080` 分开；可通过 `KUBERNETES_API_PORT` 指定 1–65535 的其它端口，容器与 Service 仍监听 `8080`。端口转发需保持入口终端运行。macOS / Windows 先通过主机 Docker 下载并导入 TiDB 镜像，避免节点重复进行公网镜像认证；Minikube 下载命令使用客户端代理并绕过集群网段，代理软件须保持可用。

## 二、服务与数据 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

API 在容器内监听 `8080`，集群外仅通过 `kubectl port-forward` 绑定主机的 `127.0.0.1:8081`。[**TiDB**](https://docs.pingcap.com/tidb/stable/) 使用 ClusterIP 服务、单副本 StatefulSet 和 5 GiB ReadWriteOnce PVC；API 启动入口等待 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 后运行建库和迁移程序。

私有资料图片使用独立 `worker-assets` 2 GiB ReadWriteOnce PVC，API 当前保持单副本；数据库内的图片元数据与该 PVC 文件必须配套保留。此清单没有跨节点对象存储或自动数据迁移能力。

程序首次启动自动初始化主管理员 `admin / admin`，无需先手动创建 Secret。在 `/admin/` 登录后进入“设置”管理账号、权限和封停；普通账号不能审核身份、新增用户或修改他人密码。已有密码和状态不会被再次部署覆盖。已有 `repair-admin` Secret 仍可作为旧环境兼容配置，但不影响默认账号的首次自动创建。`/portal/` 用于用户／师傅 PC 扫码授权，手机退出仅撤销手机当前会话。

清单中的 API 使用 `imagePullPolicy: Never`，所以平台入口必须先构建并把镜像导入当前 [**K3s**](https://docs.k3s.io/) / [**Minikube**](https://minikube.sigs.k8s.io/docs/) 集群，再应用工作负载。更新代码时，入口会重建镜像并滚动重启 API。

readiness 使用 `/readyz` 确认数据库和版本迁移就绪；startup / liveness 使用 `/healthz`。容器显式启用 `ALLOW_DEMO_NETWORK=true`，集群外发布仍限回环端口转发。镜像使用演示 `:local` 标签和构建时间版本标签，重复构建后入口会主动滚动重启 API。

Linux 固定使用 `/etc/rancher/k3s/k3s.yaml`，不继承 `KUBECONFIG`；服务地址必须为本机回环，节点必须恰好一台且 machine-id 与 `/etc/machine-id` 一致。首次安装拒绝 `K3S_*` / `INSTALL_K3S_*` 外部覆盖，避免意外加入远端集群；仅输出变量名称。已有多节点或其它主机集群直接拒绝，不能把本入口用于生产多节点镜像分发。

macOS / Windows 为保留已经部署的 PVC，继续使用显式 `minikube` profile；首次创建单节点，已有 profile 必须为 Docker 驱动单节点，复用前展示 namespace 范围并确认归属，回车取消。使用 `--keep-context` 保留用户 current-context，kubectl 命令固定 `--context=minikube`。拒绝 `MINIKUBE_HOME` / `KUBECONFIG` 覆盖；不搬迁或删除其它 profile 数据。

固定组件版本与校验规则见 [共享版本清单](../../Shared/README.md)。Docker 命名卷与 Kubernetes PVC 互相独立，本入口不自动迁移业务数据；切换路线应另做逻辑导出/导入、迁移版本校验与业务验收。

## 三、部署边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

该清单用于本地/单机编排演示。[**Linux**](https://www.kernel.org/) [**K3s**](https://docs.k3s.io/) 的 [**Kubernetes**](https://kubernetes.io/) 服务留在主机上；退出入口只会结束端口转发。macOS/Windows [**Minikube**](https://minikube.sigs.k8s.io/docs/) 由 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 承载。当前无 Ingress、外网 Service、TLS、自动扩缩容或高可用 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 配置。[**Windows**](https://www.microsoft.com/windows) ARM64 因当前 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 官方发布物缺少 [**Windows**](https://www.microsoft.com/windows) ARM64 二进制而不支持此路线。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入同级的 [`unDeployment`](../../../unDeployment/README.md) 选择对应系统入口，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
