# <font id=前言>完整反安装公共组件</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

本目录的函数由各平台 `uninstall` 入口加载，不能独立运行。详细操作见 [反安装说明](../README.md)。

## 一、实现职责 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 职责 |
| --- | --- |
| `uninstall-linux.sh` | 包管理器识别、停机归档、K3s 官方卸载、Docker 软件包与标准数据路径清理 |
| `uninstall-macos.zsh` | 停机归档、Minikube profiles 清理、Docker Desktop 官方卸载与残留核验 |
| `uninstall-windows.ps1` | 数据归档、官方卸载器、Docker 专用 WSL 清理、重启状态与失败传播 |

## 二、执行约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

入口先显示自述并等待回车，随后检查环境、选择数据策略，再要求输入 `YES`。保留数据采用“先停服备份、验证归档，再卸载”，不是卸载后尝试恢复已经删除的数据。失败停止并保留日志；重跑会重新检查已安装内容。

Linux 在确认前及备份前检查 Docker 配置、systemd 参数和 daemon 的 live-restore 状态；启用时停止。停止服务后再次检查 runtime shim、dockerd、K3s server、TiDB writer，进程仍在或状态无法检查时不归档、不进入卸载。不会自动关闭 live-restore 或强杀未知进程。

手工 Compose / Buildx 插件按本项目安装记录与当前 SHA256 精确删除；归属不明或已被其它安装修改时保留并报错，不宣称完整清场。macOS / Windows 的 Docker 与 Minikube 操作也验证并固定标准本机 daemon，不采用存储的远端 context。

门禁测试见 [部署隔离检查](../../Deployment/Tests/README.md)，真实卸载和恢复仍须在可丢弃目标机验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
