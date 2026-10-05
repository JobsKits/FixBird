# <font id=前言>[**Windows**](https://www.microsoft.com/windows) · [**Docker**](https://www.docker.com/) 部署</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 一、适用环境 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

此路线使用 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 与 [**WSL 2**](https://learn.microsoft.com/windows/wsl/)，目标为当前受支持的 [**Windows**](https://www.microsoft.com/windows) 10/11 客户端版本；脚本预检 [**Windows**](https://www.microsoft.com/windows) 10 22H2（Build 19045）或 [**Windows**](https://www.microsoft.com/windows) 11 23H2（Build 22631）起的系统。要求 64 位架构、硬件虚拟化和 [**WSL 2**](https://learn.microsoft.com/windows/wsl/).1.5 或更新版本。[**Windows**](https://www.microsoft.com/windows) Server 不支持此 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 路线。

[**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 系统要求会变动，请核对[官方 Windows 安装说明](https://docs.docker.com/desktop/setup/install/windows-install/)。[**Docker Desktop**](https://www.docker.com/products/docker-desktop/) ARM64 当前仍按其官方状态提供；需另行核对 ARM 版本兼容性和许可条件。

## 二、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行 `deploy.ps1`。[**Windows**](https://www.microsoft.com/windows) 对 `.ps1` 的普通双击行为由文件关联和执行策略决定，可能打开编辑器；请在文件上右键选择“使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行”，或在 [**PowerShell**](https://learn.microsoft.com/powershell/) 中进入此文件夹后运行：

```powershell
.\deploy.ps1
```

入口会先显示脚本自述，并等待按回车确认；按 Ctrl+C 可取消。
脚本兼容默认 Windows PowerShell 5.1，部署与反部署 PS1 统一 UTF-8 BOM；编辑时保留 BOM，避免中文在系统 ANSI 编码下误解析。安装器先验证固定 SHA256 和 Docker Authenticode 签名。

Docker context 必须指向标准本机 named pipe，后续命令显式固定端点，不切换全局 context；远端 daemon / builder 环境覆盖会拒绝。版本与下载维护见 [共享组件说明](../../Shared/README.md)。
若 WSL 未安装或版本不足，脚本会请求安装/更新；系统可能显示 UAC 提权窗口并要求重启。首次启动 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) 需要用户接受许可条款。

## 三、部署内容 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

脚本检测系统版本和 CPU 架构，按需安装 [**Docker Desktop**](https://www.docker.com/products/docker-desktop/)，之后构建 [**Go**](https://go.dev/) API 镜像并启动 [**TiDB**](https://docs.pingcap.com/tidb/stable/) 和 [**Web**](https://developer.mozilla.org/en-US/docs/Web) 管理后台。[**Go**](https://go.dev/) SDK 不安装到 [**Windows**](https://www.microsoft.com/windows)。成功后自动打开 `http://127.0.0.1:8080/admin/`。

日志位于 `%LOCALAPPDATA%\RepairMarketplace\Logs\docker-deployment.log`。API 与数据库默认仅绑定本机；账号会话与管理员首次创建见[共享说明](../Shared/README.md)，匿名演示身份仅操作演示订单。生产运行配置仍在后续阶段。

## 四、完整反安装 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

运行反部署目录中的 [`uninstall.ps1`](../../../unDeployment/Docker/Windows/uninstall.ps1)，在运行时选择“先备份再卸载”（默认）或“永久清空数据”，然后输入完整 `YES`。脚本会卸载本机共享容器运行环境，影响两条部署路线及其它容器项目。源码保留；备份失败停止卸载。详细范围、备份恢复、日志与限制见 [完整反安装说明](../../../unDeployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
