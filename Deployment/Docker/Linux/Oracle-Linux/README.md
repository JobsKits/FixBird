# <font id=前言>[**Oracle Linux**](https://www.oracle.com/linux/) · [**Docker**](https://www.docker.com/) 一键部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用系统 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此入口面向 [**Oracle Linux**](https://www.oracle.com/linux/) 8、9、10 的 64 位云主机镜像。运行时读取 `/etc/os-release` 校验发行版和版本，并检测 `x86_64` / `aarch64`；不匹配或不支持的架构会停止。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在项目目录中打开此发行版文件夹并运行 `deploy.sh`。脚本启动后会先打印自述并等待回车；按 Ctrl+C 可取消。没有可交互输入时，脚本会退出且不执行部署。桌面 [**Linux**](https://www.kernel.org/) 可选择“在终端中运行”；远程主机可执行：

```sh
./deploy.sh
```

脚本按需安装 [**Docker Engine**](https://docs.docker.com/engine/)、Compose，构建 [**Go**](https://go.dev/) API 镜像，启动 API、管理后台和 [**TiDB**](https://docs.pingcap.com/tidb/stable/)。[**Go**](https://go.dev/) 编译器与应用依赖位于容器构建阶段，宿主机不安装 [**Go**](https://go.dev/) 工具链。系统包安装和 [**Docker**](https://www.docker.com/) 服务启用会通过 `sudo` 执行。

[**Docker**](https://www.docker.com/) 官方对不同发行版的验证范围不同；该目录提供云镜像检测和安装入口，不代表 [**Docker**](https://www.docker.com/) 上游对每个衍生发行版都提供正式支持。若官方安装脚本与 [**Docker**](https://www.docker.com/) CE 仓库均不支持当前镜像，部署会停止并保留诊断日志。

## 三、配置、访问和日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

默认后台地址为 `http://127.0.0.1:8080/admin/`，健康检查为 `http://127.0.0.1:8080/healthz`。配置文件位于 `Deployment/Docker/Shared/.env`（本入口目录到配置文件的相对路径为 `../../Shared/.env`），首次运行会从 `.env.example` 创建，之后不会覆盖。默认仅监听本机地址。日志写入 当前用户状态目录中的 `repair-platform-docker.log`。

## 四、部署边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此路线面向本机预览和单机验证，接口仍使用无鉴权演示身份。不要将 API 或 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 端口直接开放到公网。需要从另一台设备调试时，应先建立 [**SSH**](https://www.openssh.com/) 隧道或可信 VPN；修改监听地址前还需配置云安全组与主机防火墙。

目标选择、固定版本、下载校验和就绪检查见 [共享部署说明](../../Shared/README.md) 与 [共享版本清单](../../../Shared/README.md)。本入口只处理已确认的标准本机环境，远端目标或不符合单节点边界时停止。

## 五、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.sh`](../../../../unDeployment/Docker/Linux/Oracle-Linux/uninstall.sh)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
