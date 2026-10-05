# <font id=前言>[**Docker**](https://www.docker.com/) Shared 部署组件</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

此目录保存 [**Docker**](https://www.docker.com/) 路线共用的镜像、Compose 配置、默认环境变量和平台安装函数。各系统入口只负责校验平台并调用此处的部署实现。

## 一、文件用途 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- `Dockerfile`：多阶段构建 [**Go**](https://go.dev/) API 和迁移程序；使用 [**Go**](https://go.dev/) 1.26.8 Alpine 构建，最终镜像包含二进制、SQL 迁移、独立演示种子、WebAdmin 与 Web PC 入口静态文件；镜像版本标签记录演示构建时间。
- 构建依赖：先复制 `Server/go.mod` 与 `Server/go.sum` 并下载模块，再复制源码编译。修改服务端依赖时运行 `go mod tidy`，保持间接依赖和校验记录完整；Docker / Kubernetes 两条路线共用此 Dockerfile。
- 构建上下文排除本机 `Server/.env`、`Server/private-uploads` 和 Kubernetes `admin.env`；运行时私有图片通过独立卷保存。
- `compose.yaml`：使用 `repair-marketplace` 固定项目名启动 [**TiDB**](https://docs.pingcap.com/tidb/stable/) v8.5.8 和 [**Go**](https://go.dev/) API。[**TiDB**](https://docs.pingcap.com/tidb/stable/) 数据使用命名卷。
- `.env.example`：本地回环地址、API 端口、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 端口和镜像版本的默认值。
- `entrypoint.sh`：等待 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 可连接后执行数据库创建 / SQL 迁移，再启动 API。
- `linux-functions.sh`、`deploy-linux.sh`：[**Linux**](https://www.kernel.org/) 发行版识别、架构检测、[**Docker Engine**](https://docs.docker.com/engine/) / Compose 安装、服务部署和健康检查。
- `macos-functions.zsh`：包含下载超时、三次重试及本地官方 DMG 回退，按 Intel / Apple Silicon 下载 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 并启动 Compose。
- `deploy-windows.ps1`：检查 [**Windows**](https://www.microsoft.com/windows) / [**WSL 2**](https://learn.microsoft.com/windows/wsl/)，准备 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)、部署 Compose，并保留失败日志。

## 二、配置与执行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

平台部署入口会先打印自述并等待回车确认；按 Ctrl+C 可取消，没有交互输入时会退出。首次运行会将 `.env.example` 复制到 `.env`，不会覆盖已有值。 Compose 工作目录固定为本目录，`compose.yaml` 中的 `../../..` 构建上下文由此定位到项目根目录，不受终端当前目录或项目移动影响。默认 `API_BIND_ADDRESS=127.0.0.1` 与 `TIDB_BIND_ADDRESS=127.0.0.1`。仅在可信内网联调时才更改 API 绑定地址；账号、私有资料和账务采用服务端会话认证，固定匿名订单演示仍可通过 `ALLOW_ANONYMOUS_DEMO` 关闭。

主管理员由程序首次启动自动初始化，默认账号和密码均为 `admin`，无需手动填写 `.env`。管理员登录 `/admin/` 后在“设置 → 账号管理”新增账号，选择管理员或普通账号；管理员可审核身份、新增账号、修改任何用户密码和封停账号。普通账号可处理业务、查询账务和修改自己的密码，不能进入身份审核或账号管理。封停和密码修改会撤销旧会话；重复部署不会覆盖已有密码、权限或账号状态。旧 `ADMIN_BOOTSTRAP_*` 配置只保留兼容能力，不是必填项。

部署后用管理员账号访问 `/admin/`，审核师傅图片资料并查询／导出账务。用户和师傅的 PC 入口为 `/portal/`，可由已登录手机扫码授权。`SESSION_TTL_HOURS` 默认24；各设备会话独立，手机退出不撤销 PC 会话。

数据库使用 `tidb-data` 命名卷；私有审核图片使用 `worker-assets` 命名卷，重建 API 容器保留图片。账号、图片元数据与图片文件需要作为同一份业务数据保留；只保留数据库无法恢复图片。完整反安装仍按操作者选择备份或删除容器数据。图片没有公共下载 URL，读取必须带本人或管理员会话。

日志位于每个用户/系统对应的日志目录，具体见入口目录 README。部署脚本会联网下载容器镜像和所需平台工具；这些容器以单机演示为目标。

macOS 两条路线共用 `configure_docker_desktop_proxy`：从系统读取 HTTP/HTTPS 代理，显示配置内容及全局重启影响并等待回车，再检查代理连通性、备份设置，通过 [Docker 官方安装器代理参数](https://docs.docker.com/desktop/setup/install/mac-install/#proxy-configuration) 应用配置并重新启动 Docker Desktop。备份位于 `~/Library/Logs/RepairMarketplace/docker-proxy-backup.*`；没有系统 HTTP/HTTPS 代理时保留原设置。仅有 SOCKS / PAC 不自动转换，不支持相关官方命令的旧版 Docker Desktop 会提示更新并停止部署。

macOS 的 `run_docker_with_proxy` 为 Compose / `docker build` 命令临时设置大小写 HTTP/HTTPS 代理变量，避免本机 Buildx 认证请求遗漏代理；仅绕过本机回环地址，不继承可能让 Docker Hub 直连的客户端 `NO_PROXY`。这些变量不写入 Shell 配置，也不影响 Minikube 命令。

代理模式、地址和绕过列表与现有 Desktop 设置相同时直接复用，配置变化时才备份、应用并重启，避免重复部署反复要求管理员密码。运行时仍会等待回车确认使用代理。

Linux 入口先加载本目录函数库；复用已运行的 Engine，缺少 Compose 或 Buildx 时单独补齐插件。下载设超时与重试，本机健康检查绕过代理并设短超时。需要 sudo 执行 Docker 命令时显式保留客户端 HTTP/HTTPS 代理变量；这不替代 Docker daemon 自身的代理配置。

Windows 两条路线读取客户端代理环境或 Windows 系统代理，展示地址并等待回车后，只在 Docker / Minikube 命令执行期间应用代理，结束后还原环境。Desktop 后台保留自身设置；客户端代理不能替代 Desktop 后台配置。WSL 版本检查兼容中文标签，下载最多三次尝试；Minikube 下载先校验版本再替换现有工具。

组件版本、架构下载地址与 SHA256 统一见 [共享版本清单](../../Shared/README.md)。缺失组件按固定版本安装，健康组件复用；标准本机 socket / named pipe 验证失败时退出。全部 Docker 命令显式固定当前已确认的本机端点，镜像构建使用该 daemon 的默认 builder，不切换用户全局 context。

Linux 手工安装的 Compose / Buildx 在 `/var/lib/repair-marketplace-deployment/owned-plugins.tsv` 记录路径和摘要，反安装只删除归属记录及摘要相符的插件。归属不明、文件被修改或符号链接均不覆盖。

容器明确设置 `ALLOW_DEMO_NETWORK=true` 以允许容器内部监听；宿主机仍按回环或已确认局域网配置发布。部署成功判定使用 `/readyz` 验证数据库和迁移状态，`/healthz` 仅反映 API 进程存活。

### 2.1、手机真机联调 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

手机中的 `127.0.0.1` 指向手机自己。真机与 Mac 连接同一可信局域网后，在本目录 `.env` 配置 `API_LAN_BIND_ADDRESS=192.168.1.7`（当前 Mac 地址，换网后需要更新），并运行相应系统的一键部署入口。需要单独调整已有容器绑定时，可从本目录运行：

```sh
docker compose --project-name repair-marketplace -f compose.yaml -f compose.lan.yaml up -d --no-deps api
```

`compose.lan.yaml` 只追加指定网卡的 API 端口，不发布到所有网卡；原有 `127.0.0.1:8080` 与数据库回环绑定保留。手机测试头 URL 填 `http://192.168.1.7:8080`；Web 后台打开同一地址的 `/admin/`，PC 扫码入口为 `/portal/`。该 HTTP 入口仅供可信内网联调；真实运营的 HTTPS 和生产数据库仍属后续阶段。

各平台部署入口每次均重新构建当前源码，再部署 API；`.env` 中 `API_LAN_BIND_ADDRESS` 非空时自动同时加载 `compose.yaml` 和 `compose.lan.yaml`，不再因重复部署丢失真机入口。该项留空则仅加载基础配置。仅撤销局域网绑定可运行 `docker compose --project-name repair-marketplace -f compose.yaml up -d --no-deps api`。IP 变化时同时修改 `.env` 和 iOS Debug 测试地址。

API 请求失败 / 超时仍保留本地演示，成功后使用真数据；空列表包含重新加载入口，网络 Logo 失败保留打包 Logo。离线预览可运行 iOS 或直接打开 `WebAdmin/index.html`。

## 三、[**TiDB**](https://docs.pingcap.com/tidb/stable/) 说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

容器使用 [**TiDB**](https://docs.pingcap.com/tidb/stable/) v8.5.8 `--store=unistore --path=/data/tidb`，数据保存在命名卷中。此模式用于本地预览，不提供分布式 TiKV 集群、备份或高可用。正式环境需要另行设计 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 集群/托管实例、账号权限、TLS、备份与迁移策略。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

进入同级的 [`unDeployment`](../../../unDeployment/README.md) 选择对应系统入口，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
