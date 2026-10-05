# <font id=前言>部署版本与下载校验</font>

![Jobs出品，必属精品](../../README-banner.svg)

[toc]

---

本目录维护两条部署路线的版本清单和共享校验函数。`components.sh` 仅定义函数，不能当安装入口运行。

## 一、文件与版本

`components.env` 保存固定版本、官方下载地址和 SHA256。当前缺失组件的安装版本为 [**Docker Desktop**](https://docs.docker.com/desktop/release-notes/) 4.93.0、[**Minikube**](https://github.com/kubernetes/minikube/releases/tag/v1.39.0) v1.39.0、[**Compose**](https://github.com/docker/compose/releases/tag/v5.6.0) v5.6.0、[**Buildx**](https://github.com/docker/buildx/releases/tag/v0.37.2) v0.37.2、[**K3s**](https://github.com/k3s-io/k3s/releases/tag/v1.37.1%2Bk3s1) v1.37.1+k3s1。已健康的本机组件直接复用；不会为对齐清单自动升级。

Docker Engine 的便捷安装脚本固定到官方仓库提交并校验 SHA256；软件包由官方或发行版签名仓库提供，实际包版本由目标系统的仓库决定。K3s 的安装脚本和安装版本均固定，其安装器会验证下载的二进制。容器内 [**Go**](https://go.dev/) 默认 1.26.8、演示 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 默认 v8.5.8；Dockerfile、示例配置和 Kubernetes 清单中的对应值由隔离测试核对，已有 `.env` 的覆盖值保留。

## 二、下载与目标约定

下载必须先通过清单的 SHA256 校验，再执行或替换软件。macOS 的 Docker DMG 还需通过镜像完整性及 Docker 开发者签名校验；Windows 安装器还需通过 Authenticode 签名校验。人工提供 DMG 也必须匹配清单版本与摘要。下载失败、摘要不匹配或官方文件失效时安全停止；维护者重新核对官方发布物后，同时更新版本、架构对应 URL 和摘要，不能删掉校验绕过错误。

标准部署拒绝 `DOCKER_HOST`、`BUILDX_BUILDER`、`BUILDKIT_HOST` 覆盖。当前 Docker context 必须指向标准本机 socket / named pipe，后续命令显式固定该端点和默认构建器；脚本不会执行 `docker context use`。SSH、TCP、非标准 socket、rootless daemon 和架构不匹配均停止，需要用户先选择所需本机环境。相关机制见 [Docker contexts 官方文档](https://docs.docker.com/engine/manage-resources/contexts/)。

macOS 芯片识别优先读取硬件 ARM64 能力，避免 Rosetta 将 Apple Silicon 误判为 Intel。Windows 读取原生架构；Windows ARM64 的 Kubernetes 路线仍明确不支持。

## 三、维护与验证

在工程根目录运行 `bash Deployment/Tests/validate-targets.sh`；Windows 在默认 PowerShell 5.1 中运行 `& .\Deployment\Tests\validate-windows.ps1`。详细范围见 [隔离检查说明](../Tests/README.md)。测试不安装组件、修改 Docker context 或接触现有数据。

容器仍使用演示 `:local` 镜像，带构建时间版本标签；不是不可变生产发布。生产发布还需固定镜像 digest、签名和发布/回滚流程。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
