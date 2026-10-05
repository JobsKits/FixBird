# Shared Windows Kubernetes bootstrap helpers using Docker Desktop and Minikube.

# Reuse the Docker Desktop installation and host checks from the Docker route.
. (Join-Path $PSScriptRoot '..\..\Docker\Shared\deploy-windows.ps1')

# Download the pinned Minikube binary matching the Windows CPU architecture.
function Ensure-Minikube {
    param([Parameter(Mandatory = $true)][string]$Architecture)
    if ($Architecture -ne 'amd64') {
        throw '当前 Minikube v1.39.0 没有 Windows ARM64 官方二进制；Windows ARM64 可使用 Docker 路线，Kubernetes 路线暂不支持。'
    }
    $binaryDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Minikube'
    $binaryPath = Join-Path $binaryDirectory 'minikube.exe'
    New-Item -ItemType Directory -Path $binaryDirectory -Force | Out-Null
    $env:Path = "$binaryDirectory;$env:Path"
    if (Test-Path $binaryPath) {
        $version = (& $binaryPath version --short 2>$null | Out-String)
        if ($LASTEXITCODE -eq 0 -and $version -match '^v[0-9]+\.') {
            return $binaryPath
        }
    }
    $downloadUrl = Get-DeploymentComponent 'MINIKUBE_WINDOWS_AMD64_URL'
    Write-Host "按 $Architecture 架构下载 Minikube v1.39.0。"
    $downloadPath = "$binaryPath.download-$PID.exe"
    try {
        Save-DeploymentDownload -Uri $downloadUrl -Destination $downloadPath
        Assert-DeploymentDownload -Path $downloadPath -ExpectedSha (Get-DeploymentComponent 'MINIKUBE_WINDOWS_AMD64_SHA256')
        $version = (& $downloadPath version --short 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0 -or $version.Trim() -ne (Get-DeploymentComponent 'MINIKUBE_VERSION')) { throw 'Minikube 下载文件版本检查失败。' }
        Move-Item -LiteralPath $downloadPath -Destination $binaryPath -Force
    } finally {
        if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath }
    }
    return $binaryPath
}
# 单独验证 profile 元数据，避免已有多节点集群进入安装步骤。
function Assert-MinikubeProfileMetadata {
    param([object]$Profile)
    if ($Profile.Driver -ne 'docker' -or @($Profile.Nodes).Count -ne 1 -or -not $Profile.Nodes[0].Name) { throw '已有 minikube profile 不是 Docker 驱动单节点，已停止。' }
}
# 保留 default profile 和 PVC；确认归属，拒绝其它驱动或多节点。
function Confirm-MinikubeProfile {
    if ($env:MINIKUBE_HOME -or $env:KUBECONFIG) { throw '标准部署不接受 MINIKUBE_HOME / KUBECONFIG 覆盖，请取消后重试。' }
    $profileFile = Join-Path $env:USERPROFILE '.minikube\profiles\minikube\config.json'
    if (Test-Path -LiteralPath $profileFile) {
        $profile = Get-Content -LiteralPath $profileFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-MinikubeProfileMetadata -Profile $profile
        Write-Host '将复用已有 minikube profile，保留 PVC 并更新 repair-marketplace namespace；请先核对集群归属。'
        if ([Console]::IsInputRedirected) { throw '没有交互输入，不能确认既有集群归属。' }
        if (-not (Read-Host '确认这是本项目可用的本机集群：回车取消；输入任意字符后回车复用')) { throw '已取消集群复用。' }
    } else { Write-Host '将创建本机单节点 minikube profile，不自动迁移 Docker 或其它集群数据。' }
}

# Build and deploy the local Kubernetes workload, then keep its loopback port-forward alive.
function Start-KubernetesDeployment {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $architecture = Get-RepairPlatformArchitecture
    $apiPort = 8081
    if ($env:KUBERNETES_API_PORT) {
        if ($env:KUBERNETES_API_PORT -notmatch '^\d{1,5}$' -or [int]$env:KUBERNETES_API_PORT -lt 1 -or [int]$env:KUBERNETES_API_PORT -gt 65535) {
            throw 'KUBERNETES_API_PORT 必须是 1–65535 的端口。'
        }
        $apiPort = [int]$env:KUBERNETES_API_PORT
    }
    if ($architecture -ne 'amd64') {
        throw '当前 Minikube v1.39.0 没有 Windows ARM64 官方二进制；Windows ARM64 可使用 Docker 路线，Kubernetes 路线暂不支持。'
    }
    Write-Host '啄木鸟维修平台 · Kubernetes 一键部署'
    Write-Host "系统：$((Get-CimInstance Win32_OperatingSystem).Caption)；架构：$architecture"
    Write-Host '范围：按需安装 Docker Desktop 与 Minikube 单节点集群，再部署 Go API 和 TiDB。'
    Write-Host '影响：可能安装 WSL 2 / Docker Desktop，并在本机创建 Kubernetes 工作负载。'
    $logDirectory = Join-Path $env:LOCALAPPDATA 'RepairMarketplace\Logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory 'kubernetes-deployment.log'
    Start-Transcript -Path $logPath -Append | Out-Null
    try {
        Initialize-DeploymentComponents -ProjectRoot $ProjectRoot
        Confirm-MinikubeProfile
        $null = Ensure-DockerDesktop
        Initialize-DeploymentProxy
        $minikube = Ensure-Minikube -Architecture $architecture

        Invoke-DeploymentCommand -Command $minikube -Arguments @('start', '--keep-context', '--driver=docker', '--cpus=2', '--memory=4096', '--disk-size=20g')
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'Minikube 集群启动失败；请检查 Docker Desktop、WSL 2 与虚拟化设置。'
        }
        $imageTag = 'repair-marketplace-api:local'
        $dockerfile = Join-Path $ProjectRoot 'Deployment\Docker\Shared\Dockerfile'
        Invoke-DeploymentCommand -Command docker -Arguments @('build', '--builder', 'default', '--platform', "linux/$architecture", '--build-arg', ('GO_VERSION=' + (Get-DeploymentComponent 'GO_VERSION')), '--build-arg', ('APP_BUILD_VERSION=demo-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')), '--file', $dockerfile, '--tag', $imageTag, $ProjectRoot)
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'Go API 容器镜像构建失败。'
        }
        Invoke-DeploymentCommand -Command $minikube -Arguments @('image','load',$imageTag)
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw '应用镜像导入 Minikube 失败。'
        }
        Invoke-DeploymentCommand -Command docker -Arguments @('pull', 'pingcap/tidb:v8.5.8')
        if ($script:DeploymentCommandExitCode -ne 0) { throw 'TiDB 镜像下载失败。' }
        Invoke-DeploymentCommand -Command $minikube -Arguments @('image','load','pingcap/tidb:v8.5.8')
        if ($script:DeploymentCommandExitCode -ne 0) { throw 'TiDB 镜像导入 Minikube 失败。' }
        $manifest = Join-Path $ProjectRoot 'Deployment\Kubernetes\Shared\workloads.yaml'
        Invoke-DeploymentCommand -Command $minikube -Arguments @('kubectl', '--', 'apply', '-f', $manifest)
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'Kubernetes 工作负载应用失败。'
        }
        Invoke-DeploymentCommand -Command $minikube -Arguments @('kubectl', '--', '-n', 'repair-marketplace', 'rollout', 'status', 'statefulset/tidb', '--timeout=360s')
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'TiDB StatefulSet 未能就绪。'
        }
        Invoke-DeploymentCommand -Command $minikube -Arguments @('kubectl', '--', '-n', 'repair-marketplace', 'rollout', 'restart', 'deployment/repair-api')
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'Go API Deployment 重启失败。'
        }
        Invoke-DeploymentCommand -Command $minikube -Arguments @('kubectl', '--', '-n', 'repair-marketplace', 'rollout', 'status', 'deployment/repair-api', '--timeout=360s')
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw 'Go API Deployment 未能就绪。'
        }
        Write-Host 'Kubernetes 部署已就绪；保持此 PowerShell 窗口打开以维持 API 端口转发。'
        Write-Host "Web 管理后台：http://127.0.0.1:$apiPort/admin/"
        Start-Process "http://127.0.0.1:$apiPort/admin/"
        Invoke-DeploymentCommand -Command $minikube -Arguments @('kubectl', '--', '-n', 'repair-marketplace', 'port-forward', '--address=127.0.0.1', 'service/repair-api', "${apiPort}:8080")
        if ($script:DeploymentCommandExitCode -ne 0) {
            throw "API 端口转发已结束；请检查本机 $apiPort 端口是否被占用。"
        }
    } finally {
        Stop-Transcript | Out-Null
    }
}
