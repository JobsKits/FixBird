# 脚本自述：
# - 脚本名称：Docker/Windows 一键部署
# - 核心用途：部署 Docker Desktop、Go API、Web 管理后台和 TiDB；完成后自动打开后台页面。
# - 影响范围：可能安装 WSL 2 / Docker Desktop / Minikube，并启动本项目服务。
# - 运行提示：在受支持的 Windows PowerShell 中执行；首次使用可能要求提权或重启。

$ErrorActionPreference = 'Stop'

# Load the shared Windows deployment flow and invoke this route.
function Invoke-RepairPlatformDeployment {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $helperPath = Join-Path $PSScriptRoot '..\Shared\deploy-windows.ps1'
    $dockerfilePath = Join-Path $projectRoot 'Deployment\Docker\Shared\Dockerfile'
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        throw "未找到 Docker 部署共享脚本：$helperPath"
    }
    if (-not (Test-Path -LiteralPath $dockerfilePath -PathType Leaf)) {
        throw "无法从入口位置定位项目 Dockerfile：$dockerfilePath"
    }
    . $helperPath
    Start-DockerDeployment -ProjectRoot $projectRoot
}

$deploymentExitCode = 0
try {
    Write-Host ''
    Write-Host '啄木鸟维修平台 · Docker 一键部署'
    Write-Host "脚本入口：$PSCommandPath"
    Write-Host '范围：按需准备 Docker Desktop，并部署 Go API、Web 管理后台和 TiDB。'
    Write-Host '影响：可能安装 WSL 2 / Docker Desktop，并启动本项目服务。'
    Write-Host '取消方式：按 Ctrl+C 取消；日志保存在当前用户的 RepairMarketplace 日志目录。'
    if ([Console]::IsInputRedirected) { throw '请在可交互的 Windows PowerShell 终端运行。' }
    $null = Read-Host '已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消'
    Invoke-RepairPlatformDeployment
} catch {
    $deploymentExitCode = 1
    Write-Host "部署失败：$($_.Exception.Message)" -ForegroundColor Red
} finally {
    Read-Host '部署流程结束。按回车关闭此窗口' | Out-Null
}
if ($deploymentExitCode -ne 0) {
    exit $deploymentExitCode
}
