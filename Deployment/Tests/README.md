# <font id=前言>部署隔离检查</font>

![Jobs出品，必属精品](../../README-banner.svg)

[toc]

---

此目录只检查脚本门禁和源码，不连接真实 daemon 或集群，不下载、安装、部署、备份或卸载。Linux 函数测试的临时样本在退出时删除。

## 一、运行方式

在工程根目录执行：

```sh
bash Deployment/Tests/validate-targets.sh
```

在 Windows 默认 [**PowerShell**](https://learn.microsoft.com/powershell/) 5.1 执行：

```powershell
& .\Deployment\Tests\validate-windows.ps1
```

不需要管理员权限；不要运行平台安装/卸载入口来代替此测试。

## 二、覆盖范围

| 入口 | 验证内容 |
| --- | --- |
| `validate-targets.sh` | 标准本机 Docker 端点、远端/环境/构建器拒绝、下载摘要与清单默认值一致性、固定 K3s kubeconfig 的单节点与 machine-id 归属、安装器外部覆盖拒绝、live-restore 与残留 writer 拒绝、手工 Buildx 插件归属/摘要/链接；有 zsh 时检查 Rosetta 硬件识别与 Minikube 节点元数据 |
| `validate-windows.ps1` | 全部部署/反部署 PS1 UTF-8 BOM 与 Parser；本机 named pipe、Minikube profile/context 固定、远端/环境/构建器和多节点/其它驱动拒绝 |

函数替身测试不证明目标操作系统的安装、UAC、systemd、网络、签名服务或数据库恢复已经通过。macOS 临时 PowerShell 运行包可解析和执行替身测试，但 Windows 5.1 的实际解析应由 Windows CI / 实机完成。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
