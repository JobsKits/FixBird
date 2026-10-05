# <font id=前言>Kubernetes/Linux/Oracle-Linux 完整反安装</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、用途与影响 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本入口与 [部署入口](../../../../Deployment/Kubernetes/Linux/Oracle-Linux/README.md) 对应。卸载本机容器运行环境；两个部署路线及其它容器项目都会受影响。保留源码和脚本，清理实际部署配置。完整范围与平台限制见 [反安装总说明](../../../README.md)。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在当前目录的交互式终端执行；macOS 支持双击，Windows 需要以部署账户打开管理员 PowerShell，Linux 的系统操作会请求 sudo 权限。

```sh
bash ./uninstall.sh
```

先阅读自述并回车，再选择 `1`（默认，先备份再卸载）或 `2`（永久删除数据），最后输入完整 `YES`。其它确认输入取消；按 Ctrl+C 可终止，没有交互输入时退出。

## 三、备份、日志与验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

备份放在当前用户的 `RepairMarketplaceBackups/时间戳-进程号/`，日志放在系统临时目录的 `repair-uninstall-*` 文件。备份失败停止卸载；数据可能包含数据库和凭据配置，应妥善保存。恢复方式、非标准环境限制与未执行声明见总说明。脚本未经真实目标主机卸载验收，不要把静态检查视为数据恢复验证。

Linux 的 live-restore、残留写入者和手工插件归属门禁见 [公共反安装说明](../../../Shared/README.md)；门禁失败不执行归档或继续卸载。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
