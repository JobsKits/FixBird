# 脚本自述：
# - 核心用途：卸载 Docker Desktop / Minikube / Docker 专用 WSL 环境。
# - 影响范围：全部容器项目；运行时选择先备份或永久清空数据。
# - 运行提示：以当前账户管理员 PowerShell 执行；输入 YES 才卸载，Ctrl+C 取消。

# 先显示说明并等待用户阅读，随后才加载反安装逻辑。
function Main {
    $ErrorActionPreference = 'Stop'
    Write-Host '啄木鸟维修平台 · Windows 完整反安装'
    Write-Host '卸载两条部署路线的运行环境；其它容器项目也受影响。'
    Write-Host '稍后选择备份或永久删除；备份位于用户 RepairMarketplaceBackups，日志位于系统临时目录。'
    if ([Console]::IsInputRedirected) { throw '请使用可交互的管理员 PowerShell。' }
    $null = Read-Host '已了解范围，按回车继续；Ctrl+C 取消'
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    if (-not (Test-Path (Join-Path $projectRoot 'Deployment\Docker\Shared\compose.yaml'))) { throw '项目路径无效。' }
    . (Join-Path $PSScriptRoot '..\..\Shared\uninstall-windows.ps1')
    Start-RepairCleanup -ProjectRoot $projectRoot
}

try { Main } catch {
    Write-Host "反安装未完成：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
