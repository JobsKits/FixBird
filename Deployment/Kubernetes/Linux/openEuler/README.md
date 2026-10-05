# <font id=前言>[**openEuler**](https://www.openeuler.org/) · [**Kubernetes**](https://kubernetes.io/) 一键部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用系统 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此入口面向 [**openEuler**](https://www.openeuler.org/) 20.03、22.03、24.03 LTS 的 64 位云主机镜像。运行时读取 `/etc/os-release` 校验发行版和版本，并检测 `x86_64` / `aarch64`；不匹配或不支持的架构会停止。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在项目目录中打开此发行版文件夹并运行 `deploy.sh`。脚本启动后会先打印自述并等待回车；按 Ctrl+C 可取消。没有可交互输入时，脚本会退出且不执行部署。桌面 [**Linux**](https://www.kernel.org/) 可选择“在终端中运行”；远程主机可执行：

```sh
./deploy.sh
```

脚本按需安装 [**Docker Engine**](https://docs.docker.com/engine/)（用于构建镜像）和 [**K3s**](https://docs.k3s.io/) 单节点集群，将本地 [**Go**](https://go.dev/) API 镜像导入 [**K3s**](https://docs.k3s.io/)，再部署 API、管理后台和 [**TiDB**](https://docs.pingcap.com/tidb/stable/) StatefulSet。宿主机不安装 [**Go**](https://go.dev/) 工具链。系统包安装、[**Docker**](https://www.docker.com/) 和 [**K3s**](https://docs.k3s.io/) 服务配置会通过 `sudo` 执行。

## 三、配置、访问和日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**K3s**](https://docs.k3s.io/) 使用本机 [**Kubernetes**](https://kubernetes.io/) 工作负载。部署完成后，脚本通过 `127.0.0.1:8081` 端口转发访问后台 `http://127.0.0.1:8081/admin/` 和健康检查 `/healthz`。保持部署终端运行以保留端口转发；关闭终端后，[**K3s**](https://docs.k3s.io/) 工作负载仍留在主机上。日志写入 当前用户状态目录中的 `repair-platform-kubernetes.log`，[**K3s**](https://docs.k3s.io/) 服务日志可使用 `journalctl -u k3s` 查看。

## 四、部署边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此路线是单节点演示集群，不提供高可用、自动扩容、外网入口或生产级 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 集群。API 使用无鉴权演示身份；不要将端口直接开放到公网。[**CentOS Linux**](https://www.centos.org/centos-linux/) 7/8、[**Amazon Linux**](https://aws.amazon.com/linux/amazon-linux-2023/) 2 等已停止维护的系统不在支持范围内。

目标选择、固定版本、下载校验和就绪检查见 [共享部署说明](../../Shared/README.md) 与 [共享版本清单](../../../Shared/README.md)。本入口只处理已确认的标准本机环境，远端目标或不符合单节点边界时停止。

## 五、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.sh`](../../../../unDeployment/Kubernetes/Linux/openEuler/uninstall.sh)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
