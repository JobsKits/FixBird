# 完整反安装与数据处理

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

反安装负责卸载 [**Docker**](https://www.docker.com/) 和本项目使用的本地 [**Kubernetes**](https://kubernetes.io/) 运行环境，清理部署配置，使标准部署入口可以重新安装。它不是暂停服务，也不是系统快照回滚：不会把操作系统软件版本、系统日志和共享基础工具恢复到某个历史时刻。

**是否保留数据在运行反安装脚本时选择。默认先备份，再卸载；只有选择永久删除才直接清空数据。两种模式都卸载运行环境，均需输入完整 `YES`。**

## 一、入口与运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本目录与 `../Deployment/` 同级，按相同的路线、操作系统和发行版提供 `uninstall.sh`、`uninstall.command`、`uninstall.ps1`，共 38 个入口；部署与反部署脚本分开存放。两条路线共用本机运行环境，从任一路线运行反安装，都会影响另一条路线及其它容器项目。

| 平台 | 从本文档目录运行的示例 | 权限 |
| --- | --- | --- |
| [**Linux**](https://www.kernel.org/) | `bash ./Docker/Linux/Ubuntu/uninstall.sh` | 以部署账户运行，系统操作使用 sudo；选择对应发行版 |
| [**macOS**](https://www.apple.com/macos/) | `zsh ./Docker/macOS/uninstall.command` | 支持 Finder 双击；卸载应用可能请求管理员权限 |
| [**Windows**](https://www.microsoft.com/windows) | `& .\Docker\Windows\uninstall.ps1` | 以部署账户打开管理员 PowerShell；不要切换账户 |

入口先打印自述并等待回车，然后选择数据策略，最后输入 `YES`。任何其它确认输入取消；没有可交互输入时退出。没有自动确认参数，避免双击或自动任务误清场。请先关闭部署入口的端口转发窗口。

## 二、运行时数据选择 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 选择 | 行为 | 数据结果 |
| --- | --- | --- |
| `1` 或直接回车 | 停止写入，归档标准数据目录，检查归档可读取，再卸载 | 数据留在当前用户主目录的 `RepairMarketplaceBackups/时间戳-进程号/` |
| `2` | 卸载运行环境并清空标准数据目录 | 所有相关容器、镜像、卷、集群数据永久删除，不自动备份 |

范围包括其它项目的容器和集群。源码、部署脚本与 `.env.example` 保留；实际生成的 `../Deployment/Docker/Shared/.env` 在卸载时清理，备份模式会将其归档。备份目录和本次审计日志不属于清理目标。

备份需要足够磁盘空间；虚拟磁盘和容器目录可能很大。归档失败、权限不足、磁盘已满或运行环境不能正常停止时，中止卸载，不显示成功。服务可能已经停止，需要自行重新启动。归档可能包含数据库与本机凭据配置，请按敏感数据保管。

## 三、各平台卸载范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 平台 | 软件与数据 |
| --- | --- |
| Linux | [**K3s**](https://docs.k3s.io/installation/uninstall) 官方卸载器清理整个本地集群；系统包管理器卸载 Docker Engine、Compose、Buildx、containerd / runc；清理标准数据、配置、Docker 软件源与本项目记录且摘要相符的手工 Compose / Buildx 插件 |
| macOS | [**Minikube**](https://minikube.sigs.k8s.io/docs/commands/delete/) 删除当前用户全部 profiles 和缓存；卸载部署脚本安装的二进制及 Homebrew 管理的 Minikube；调用 [**Docker Desktop 官方卸载器**](https://docs.docker.com/desktop/uninstall/) 并删除应用与用户残留 |
| Windows | 删除当前用户全部 Minikube profiles 与标准安装目录；调用 Docker Desktop 官方卸载器；清理 Docker 专用 [**WSL**](https://learn.microsoft.com/windows/wsl/basic-commands) 发行版和应用残留；没有独立 Linux 发行版时卸载 WSL 应用并禁用相关系统组件，可能需要重启 |

Windows 中独立安装的 Ubuntu 等 WSL 发行版不会被注销；检测到它们时保留共享 WSL 并明确报告。部署入口使用 `--no-distribution`，没有创建这些独立发行版。其它用户的主目录、远程集群、宿主机上容器 bind mount 引用的业务源码目录也不递归清空。远程 Kubernetes 配置保留。

Linux 不执行全局 `autoremove`，不会盲删 curl、CA 证书等操作系统共享工具，也不会尝试降级已更新的软件包。缺少历史安装记录无法可靠判断这些基础依赖是否由某次部署新增。需要字节级恢复操作系统时，应使用部署前的虚拟机或云盘快照。

## 四、备份与恢复 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Linux 与 macOS 使用 `data.tar` 保存原始目录布局；Windows 使用编号归档和 `restore-paths.txt` 记录目标位置。归档检查验证文件可读取，不等于已经完成数据库恢复演练。

恢复前先安装兼容版本的运行环境并停止相关服务，再按归档记录还原路径、权限和虚拟磁盘；完成后检查数据库与业务。不要直接将旧 Docker 数据目录复制进正在运行的 daemon，也不要跨操作系统直接恢复虚拟磁盘。生产数据库应另做逻辑备份。脚本不自动执行还原。

## 五、失败与非标准环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本流程以现有部署脚本的标准路径为边界。自定义数据目录、rootless Docker、手工复制或其它包管理器安装的工具、其它用户的环境，不能保证自动清完。脚本对已识别的自定义环境和残留命令报错，需按输出处理后重跑。不要将未覆盖的自定义安装当作已清零。

Linux 检测到 [Docker live-restore](https://docs.docker.com/engine/daemon/live-restore/) 配置、服务参数或运行状态时拒绝继续；需先由维护者按维护计划关闭并正常重启，脚本不自动处理。停服后仍有 runtime shim、daemon、K3s server 或 TiDB writer 时，拒绝归档并停止卸载。手工 Compose / Buildx 插件必须有本项目安装收据且摘要相符；归属不明或被改动时保留并报错。

macOS / Windows 的 Docker 与 Minikube 操作固定到经过验证的标准本机 socket / named pipe，拒绝远端 context；不会更改用户全局 Docker context。

macOS 的完全磁盘访问权限可能阻止备份或移除 Docker 容器目录；请为运行脚本的终端授权后重试。官方卸载器缺失、Minikube 有数据但二进制缺失、Linux 残留挂载或软件包卸载失败均停止流程。失败可能发生在部分软件已移除之后；这是可重试的卸载流程，不是原子事务。

日志位于系统临时目录中的 `repair-uninstall-*` 文件，路径在终端输出。既有部署日志保留用于排障，不会清空系统审计记录。Windows 不自动重启；出现重启提示后，系统组件清理需重启才生效。

## 六、验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此前已通过 38 个入口配对及路径检查、Shell 语法、36 个 Shell 入口非交互门禁、双 Shell 数据模式 / 取消 / EOF 验证，以及 Linux 备份失败和残留挂载的隔离假命令验证。本次新增 [隔离检查](../Deployment/Tests/README.md) 覆盖 live-restore、残留 writer、Buildx 所有权及全部 PS1 BOM / Parser；本机 PowerShell 使用官方临时 macOS 运行包，Windows 5.1 的实际 Parser 由 Windows CI / 实机执行。未在开发电脑上执行真实卸载；实际删除、系统软件卸载、归档恢复与跨平台权限流程仍需在可丢弃的目标虚拟机验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
