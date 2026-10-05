# Shared Windows bootstrap helpers for Docker Desktop and Compose.

# 读取 ASCII 键值清单，不执行配置内容。
function Initialize-DeploymentComponents {
    param([string]$ProjectRoot)
    $script:DeploymentComponents = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $ProjectRoot 'Deployment\Shared\components.env') -Encoding UTF8) {
        if ($line -match '^([A-Z0-9_]+)=(.+)$') {
            if ($script:DeploymentComponents.ContainsKey($Matches[1])) { throw '组件清单包含重复键。' }
            $script:DeploymentComponents[$Matches[1]] = $Matches[2]
        }
    }
}
# 要求组件清单有明确值，避免缺失配置退化为 latest。
function Get-DeploymentComponent {
    param([string]$Key)
    if (-not $script:DeploymentComponents.ContainsKey($Key)) { throw "组件清单缺少字段：$Key" }
    return $script:DeploymentComponents[$Key]
}
# 先验证文件摘要，再允许执行或替换安装包。
function Assert-DeploymentDownload {
    param([string]$Path, [string]$ExpectedSha)
    if ($ExpectedSha -notmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedSha) {
        throw "下载 SHA256 校验失败：$Path；请核对官方发布物后更新清单。"
    }
}
# 校验标准本机命名管道，锁定命令目标而不切换用户全局 context。
function Select-LocalDockerTarget {
    if ($env:DOCKER_HOST) { throw '标准本机部署不接受 DOCKER_HOST 覆盖，请在当前终端取消后重试。' }
    if ($env:BUILDX_BUILDER -or $env:BUILDKIT_HOST) { throw '标准本机部署不接受构建器环境覆盖，请取消 BUILDX_BUILDER / BUILDKIT_HOST 后重试。' }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if ($env:DOCKER_CONTEXT) { throw 'Docker 尚未安装，不能验证 DOCKER_CONTEXT。' }
        $script:DeploymentDockerHost = $null
        return
    }
    $context = (& docker context show | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $context) { throw '无法读取当前 Docker context。' }
    $endpoint = (& docker context inspect $context --format '{{.Endpoints.docker.Host}}' | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $endpoint -notmatch '^npipe:/+\./pipe/(docker_engine|dockerDesktopLinuxEngine)$') {
        throw "拒绝非标准本机 Docker 目标：context=$context endpoint=$endpoint；脚本不会切换全局 context。"
    }
    $script:DeploymentDockerHost = $endpoint
    Write-Host "已固定本机 Docker 目标：context=$context endpoint=$endpoint"
}
# 确保 daemon 是匹配主机架构的 Linux 容器环境。
function Assert-DockerServerPlatform {
    param([string]$Architecture)
    Invoke-DeploymentCommand -Command docker -Arguments @('info', '--format', '{{.OSType}}/{{.Architecture}}') | ForEach-Object { $script:DeploymentDockerPlatform = "$_" }
    if ($script:DeploymentCommandExitCode -ne 0 -or $script:DeploymentDockerPlatform -notin @("linux/$Architecture", $(if ($Architecture -eq 'amd64') { 'linux/x86_64' } else { 'linux/aarch64' }))) {
        throw "Docker daemon 平台不匹配：$script:DeploymentDockerPlatform，预期 linux/$Architecture。"
    }
}
# Write a deployment message to the terminal and, when available, the transcript.
function Write-DeploymentLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message
}

# Retry official downloads without using partial files as installed tools.
function Save-DeploymentDownload {
    param([string]$Uri, [string]$Destination)
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $requestArguments = @{ UseBasicParsing = $true; Uri = $Uri; OutFile = $Destination; TimeoutSec = 1800 }
            if ($script:DeploymentHttpsProxy) { $requestArguments.Proxy = $script:DeploymentHttpsProxy }
            Invoke-WebRequest @requestArguments
            return
        } catch {
            if ($attempt -eq 3) { throw }
            Write-DeploymentLog "下载失败，正在重试（$attempt/3）。"
            Start-Sleep -Seconds 2
        }
    }
}

# Check the Windows client version and architecture required by Docker Desktop.
function Get-RepairPlatformArchitecture {
    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    $buildNumber = [int]$operatingSystem.BuildNumber
    if ($operatingSystem.Caption -notmatch 'Windows 10|Windows 11' -or $operatingSystem.ProductType -ne 1) {
        throw 'Docker Desktop 自动部署仅支持受支持的 Windows 10 / Windows 11 客户端；Windows Server 不在此路线内。'
    }
    if ($operatingSystem.Caption -match 'Windows 10' -and $buildNumber -lt 19045) {
        throw 'Windows 10 至少需要 22H2（Build 19045）；请按 Docker 当前支持矩阵升级系统。'
    }
    if ($operatingSystem.Caption -match 'Windows 11' -and $buildNumber -lt 22631) {
        throw 'Windows 11 至少需要 23H2（Build 22631）；请按 Docker 当前支持矩阵升级系统。'
    }
    $nativeArchitecture = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $nativeArchitecture = $env:PROCESSOR_ARCHITEW6432 }
    switch ($nativeArchitecture) {
        'AMD64' { return 'amd64' }
        'ARM64' { return 'arm64' }
        default { throw "不支持的 Windows CPU 架构：$env:PROCESSOR_ARCHITECTURE" }
    }
}

# Verify or prepare WSL 2 before the Docker Desktop installer is launched.
function Ensure-Wsl2 {
    $wslVersion = (& wsl.exe --version 2>$null | Out-String)
    $versionMatch = [regex]::Match($wslVersion, 'WSL[^:\r\n]*:\s*([0-9.]+)')
    if ($LASTEXITCODE -ne 0 -or -not $versionMatch.Success) {
        Write-DeploymentLog '当前未检测到新版 WSL，正在请求 Windows 安装 WSL 2；系统可能要求重启。'
        Start-Process -FilePath 'wsl.exe' -ArgumentList @('--install', '--no-distribution') -Verb RunAs -Wait
        $wslVersion = (& wsl.exe --version 2>$null | Out-String)
        $versionMatch = [regex]::Match($wslVersion, 'WSL[^:\r\n]*:\s*([0-9.]+)')
        if ($LASTEXITCODE -ne 0 -or -not $versionMatch.Success) {
            throw 'WSL 安装尚未完成。请按系统提示重启 Windows，再重新运行此 PS1。'
        }
    }
    $installedVersion = [version]$versionMatch.Groups[1].Value
    if ($installedVersion -lt [version]'2.1.5') {
        Write-DeploymentLog '正在更新 WSL，以满足 Docker Desktop 的最低版本要求。'
        & wsl.exe --update
        if ($LASTEXITCODE -ne 0) {
            throw 'WSL 更新失败；请完成 Windows 更新或重启后重试。'
        }
        $wslVersion = (& wsl.exe --version 2>$null | Out-String)
        $versionMatch = [regex]::Match($wslVersion, 'WSL[^:\r\n]*:\s*([0-9.]+)')
        if (-not $versionMatch.Success -or [version]$versionMatch.Groups[1].Value -lt [version]'2.1.5') {
            throw 'WSL 仍低于 2.1.5；请重启 Windows 并重新运行此 PS1。'
        }
    }
}

# Discover the Windows system proxy and confirm temporary client-side use.
function Initialize-DeploymentProxy {
    $script:DeploymentHttpProxy = $env:HTTP_PROXY
    $script:DeploymentHttpsProxy = $env:HTTPS_PROXY
    if (-not $script:DeploymentHttpProxy) { $script:DeploymentHttpProxy = $env:http_proxy }
    if (-not $script:DeploymentHttpsProxy) { $script:DeploymentHttpsProxy = $env:https_proxy }
    if (-not $script:DeploymentHttpsProxy) {
        $target = [uri]'https://auth.docker.io/token'
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($target)
        if ($proxy -and $proxy.AbsoluteUri -ne $target.AbsoluteUri) {
            $script:DeploymentHttpsProxy = $proxy.AbsoluteUri
        }
    }
    if (-not $script:DeploymentHttpsProxy) { $script:DeploymentHttpsProxy = $script:DeploymentHttpProxy }
    if (-not $script:DeploymentHttpProxy) { $script:DeploymentHttpProxy = $script:DeploymentHttpsProxy }
    if ($script:DeploymentHttpsProxy) {
        foreach ($address in @($script:DeploymentHttpProxy, $script:DeploymentHttpsProxy)) {
            $proxyUri = [uri]$address
            if (-not $proxyUri.IsAbsoluteUri -or $proxyUri.Scheme -notin @('http', 'https') -or $proxyUri.UserInfo) {
                throw '客户端代理必须是无嵌入凭据的 HTTP/HTTPS 地址。'
            }
        }
        Write-Host '即将为 Docker / Minikube 客户端命令临时使用检测到的代理：'
        Write-Host "  HTTP：$script:DeploymentHttpProxy"
        Write-Host "  HTTPS：$script:DeploymentHttpsProxy"
        Write-Host '不会写入系统环境变量；Docker Desktop 后台仍使用自己的网络设置。'
        $null = Read-Host '按回车确认使用上述客户端代理；按 Ctrl+C 取消'
    }
}

# Limit proxy variables to a native deployment command and restore them afterwards.
function Invoke-DeploymentCommand {
    param([string]$Command, [string[]]$Arguments)
    $saved = @{}
    $variables = @('HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'DOCKER_HOST', 'DOCKER_CONTEXT')
    try {
        foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
        $commandName = [IO.Path]::GetFileNameWithoutExtension($Command)
        if ($commandName -in @('docker','minikube')) {
            if (-not $script:DeploymentDockerHost) { throw '尚未固定本机 Docker 目标。' }
            $env:DOCKER_CONTEXT = $null
            $env:DOCKER_HOST = $null
            if ($commandName -eq 'docker') { $Arguments = @('--host', $script:DeploymentDockerHost) + $Arguments }
            else {
                $env:DOCKER_HOST = $script:DeploymentDockerHost
                $Arguments = @('--profile=minikube') + $Arguments
                if ($Arguments -contains 'kubectl') { $Arguments += '--context=minikube' }
            }
        }
        if ($script:DeploymentHttpsProxy) {
            $env:HTTP_PROXY = $script:DeploymentHttpProxy
            $env:HTTPS_PROXY = $script:DeploymentHttpsProxy
            $env:NO_PROXY = 'localhost,127.0.0.1,::1,192.168.49.0/24,192.168.59.0/24,192.168.39.0/24,10.96.0.0/12'
        }
        & $Command @Arguments
        $script:DeploymentCommandExitCode = $LASTEXITCODE
    } finally {
        foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    }
}

# Wait until the Docker Desktop engine and Compose plugin are ready.
function Wait-DockerDesktop {
    param([int]$TimeoutSeconds = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Invoke-DeploymentCommand -Command docker -Arguments @('info') *> $null
        if ($script:DeploymentCommandExitCode -eq 0) {
            Invoke-DeploymentCommand -Command docker -Arguments @('compose','version') *> $null
            if ($script:DeploymentCommandExitCode -eq 0) {
                Write-DeploymentLog 'Docker Desktop 与 Compose 已就绪。'
                return
            }
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw 'Docker Desktop 尚未就绪。首次启动时请在 Docker 窗口接受许可，然后重新运行部署脚本。'
}

# Install Docker Desktop only when the host does not already have a working engine.
function Ensure-DockerDesktop {
    $architecture = Get-RepairPlatformArchitecture
    Select-LocalDockerTarget
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCommand) {
        Invoke-DeploymentCommand -Command docker -Arguments @('info') *> $null
        if ($script:DeploymentCommandExitCode -eq 0) {
            Invoke-DeploymentCommand -Command docker -Arguments @('compose','version') *> $null
            if ($script:DeploymentCommandExitCode -eq 0) {
                Assert-DockerServerPlatform -Architecture $architecture
                Write-DeploymentLog "Docker Engine 已可用，检测架构：$architecture。"
                return $architecture
            }
        }
    }

    $desktopCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    $desktop = $desktopCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    Ensure-Wsl2
    if (-not $desktop) {
        $installer = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
        $componentKey = 'DOCKER_DESKTOP_WINDOWS_' + $architecture.ToUpperInvariant()
        $installerUrl = Get-DeploymentComponent ($componentKey + '_URL')
        Write-DeploymentLog "按 $architecture 架构下载 Docker Desktop。"
        Save-DeploymentDownload -Uri $installerUrl -Destination $installer
        Assert-DeploymentDownload -Path $installer -ExpectedSha (Get-DeploymentComponent ($componentKey + '_SHA256'))
        $signature = Get-AuthenticodeSignature -LiteralPath $installer
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(^|,)\s*(CN|O)=Docker Inc\.?(,|$)') { throw 'Docker 安装器开发者签名校验失败。' }
        $installerProcess = Start-Process -FilePath $installer -ArgumentList @('install', '--user') -Wait -PassThru
        if ($installerProcess.ExitCode -ne 0) {
            throw "Docker Desktop 安装器退出码为 $($installerProcess.ExitCode)。"
        }
        $desktop = $desktopCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $desktop) {
            throw 'Docker Desktop 安装器结束，但没有找到应用程序。请查看安装器提示并重试。'
        }
    }
    $dockerCliCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin')
    )
    $dockerCliDirectory = $dockerCliCandidates | Where-Object { Test-Path (Join-Path $_ 'docker.exe') } | Select-Object -First 1
    if ($dockerCliDirectory) {
        $env:Path = "$dockerCliDirectory;$env:Path"
    }
    Start-Process -FilePath $desktop
    Select-LocalDockerTarget
    Wait-DockerDesktop
    Assert-DockerServerPlatform -Architecture $architecture
    return $architecture
}

# Deploy the API and TiDB stack from the shared Compose definition.
function Start-DockerDeployment {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $architecture = Get-RepairPlatformArchitecture
    Write-Host '啄木鸟维修平台 · Docker 一键部署'
    Write-Host "系统：$((Get-CimInstance Win32_OperatingSystem).Caption)；架构：$architecture"
    Write-Host '范围：按需安装 Docker Desktop，再部署 Go API、Web 后台与 TiDB。'
    Write-Host '影响：可能安装 WSL 2 / Docker Desktop，并在项目内创建部署配置。'
    $logDirectory = Join-Path $env:LOCALAPPDATA 'RepairMarketplace\Logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory 'docker-deployment.log'
    Start-Transcript -Path $logPath -Append | Out-Null
    try {
        Initialize-DeploymentComponents -ProjectRoot $ProjectRoot
        $null = Ensure-DockerDesktop
        Initialize-DeploymentProxy

        $sharedDirectory = Join-Path $ProjectRoot 'Deployment\Docker\Shared'
        $environmentFile = Join-Path $sharedDirectory '.env'
        if (-not (Test-Path $environmentFile)) {
            Copy-Item (Join-Path $sharedDirectory '.env.example') $environmentFile
            Write-DeploymentLog '已创建默认部署配置：Deployment\Docker\Shared\.env'
        }
        $composeFile = Join-Path $sharedDirectory 'compose.yaml'
        $composeBase = @('compose','--project-directory',$sharedDirectory,'--project-name','repair-marketplace','--file',$composeFile)
        $lanLine = Get-Content $environmentFile | Where-Object { $_ -match '^\s*API_LAN_BIND_ADDRESS\s*=' } | Select-Object -First 1
        if ($lanLine -match '=\s*(\S+)') {
            $composeBase += @('--file', (Join-Path $sharedDirectory 'compose.lan.yaml'))
            Write-DeploymentLog ('保留局域网联调地址：' + $Matches[1])
        }
        $composeBase += @('--env-file',$environmentFile)
        Write-DeploymentLog '每次部署都会重新构建当前源码，再更新 API 容器；数据库与图片数据卷保留。'
        $composeArguments = $composeBase + @('build','--builder','default','--build-arg',('GO_VERSION=' + (Get-DeploymentComponent 'GO_VERSION')),'--build-arg',('APP_BUILD_VERSION=demo-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')))
        Invoke-DeploymentCommand -Command docker -Arguments $composeArguments
        if ($script:DeploymentCommandExitCode -ne 0) { throw 'Docker Compose 构建失败；请查看上方终端输出。' }
        Invoke-DeploymentCommand -Command docker -Arguments ($composeBase + @('up','--detach','--no-build'))
        if ($script:DeploymentCommandExitCode -ne 0) { throw 'Docker Compose 启动失败。' }

        $environment = Get-Content $environmentFile
        $portLine = $environment | Where-Object { $_ -match '^\s*API_PORT\s*=' } | Select-Object -First 1
        $apiPort = 8080
        if ($portLine -match '=\s*(\d+)') {
            $apiPort = [int]$Matches[1]
        }
        $deadline = (Get-Date).AddSeconds(180)
        do {
            try {
                $request = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$apiPort/readyz")
                $request.Proxy = $null
                $request.Timeout = 3000
                $response = $request.GetResponse()
                $healthy = [int]$response.StatusCode -eq 200
                $response.Close()
                if ($healthy) {
                    Write-DeploymentLog "部署完成：http://127.0.0.1:$apiPort/admin/"
                    Start-Process "http://127.0.0.1:$apiPort/admin/"
                    return
                }
            } catch {
                Start-Sleep -Seconds 2
            }
        } while ((Get-Date) -lt $deadline)
        Invoke-DeploymentCommand -Command docker -Arguments @('compose','--project-directory',$sharedDirectory,'--project-name','repair-marketplace','--file',$composeFile,'logs','--tail=100')
        throw '服务尚未通过健康检查；已输出最近容器日志。'
    } finally {
        Stop-Transcript | Out-Null
    }
}
