# <font id=前言>[**Windows**](https://www.microsoft.com/windows) · [**Kubernetes**](https://kubernetes.io/) 部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此路线使用 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) + [**WSL 2**](https://learn.microsoft.com/windows/wsl/) + [**Minikube**](https://minikube.sigs.k8s.io/docs/) v1.39.0，适用于受支持的 [**Windows**](https://www.microsoft.com/windows) 10/11 x64 客户端。[**Windows**](https://www.microsoft.com/windows) ARM64 当前没有 [Minikube v1.39.0 官方 Windows 二进制](https://github.com/kubernetes/minikube/releases/tag/v1.39.0)，脚本会预检后停止；请在 [**Windows**](https://www.microsoft.com/windows) ARM64 上选择 [**Docker**](https://www.docker.com/) 路线。[**Windows**](https://www.microsoft.com/windows) Server 不属于此路线。

请查看 [Docker Desktop Windows 安装要求](https://docs.docker.com/desktop/setup/install/windows-install/) 和 [Minikube 入门文档](https://minikube.sigs.k8s.io/docs/start/)。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行 `deploy.ps1`。普通双击 `.ps1` 可能打开编辑器；请右键选择“使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行”，或在 [**PowerShell**](https://learn.microsoft.com/powershell/) 中执行：

```powershell
.\deploy.ps1
```

入口会先显示脚本自述，并等待按回车确认；按 Ctrl+C 可取消。
脚本在安装前检查架构，再按需准备 [**WSL 2**](https://learn.microsoft.com/windows/wsl/)、[**Docker Desktop**](https://www.docker.com/products/docker-desktop/)、[**Minikube**](https://minikube.sigs.k8s.io/docs/)，构建镜像并应用 [**Kubernetes**](https://kubernetes.io/) 工作负载。缺少 WSL 时可能需要管理员授权或重启；首次启动 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 需要用户接受许可条款。

## 三、部署内容与限制 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Minikube**](https://minikube.sigs.k8s.io/docs/) 启动本机单节点集群，API 和 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 通过 [**Kubernetes**](https://kubernetes.io/) 清单部署。脚本将 `127.0.0.1:8081` 转发到 API；后台地址为 `http://127.0.0.1:8081/admin/`。保持 [**PowerShell**](https://learn.microsoft.com/powershell/) 窗口打开以维持转发，关闭窗口后本地集群仍由 [**Minikube**](https://minikube.sigs.k8s.io/docs/) 管理。

日志位于 `%LOCALAPPDATA%\RepairMarketplace\Logs\kubernetes-deployment.log`。此方案是本机编排演示；[**TiDB**](https://docs.pingcap.com/tidb/stable/) 单副本、API 无认证，不应作为公网生产服务。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.ps1`](../../../unDeployment/Kubernetes/Windows/uninstall.ps1)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

脚本兼容默认 Windows PowerShell 5.1，PS1 必须保留 UTF-8 BOM。下载 Minikube 时先校验固定 SHA256 再执行；健康工具直接复用。Docker 命令固定到已确认的本机 named pipe，拒绝远端 daemon / builder 环境覆盖。

已有 `minikube` profile 必须为 Docker 驱动单节点，复用前确认集群归属和 namespace 范围，回车取消；保留 PVC 与用户 current-context。具体规则见 [共享部署说明](../Shared/README.md) 和 [共享组件说明](../../Shared/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
