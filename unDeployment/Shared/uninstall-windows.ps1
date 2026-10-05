# 脚本自述：各 Windows 入口共用的完整反安装流程。
# 运行时选择先备份或永久清空；卸载 Docker Desktop、Minikube 与 Docker 专用 WSL 环境。

# 复用本机目标校验与命令封装，不执行部署入口。
. (Join-Path $PSScriptRoot '..\..\Deployment\Docker\Shared\deploy-windows.ps1')

# 检查原生命令退出码，避免 PowerShell 把卸载失败当作成功。
function Assert-CleanupExit {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation 失败，退出码：$LASTEXITCODE"
    }
}
# 清理已知路径，拒绝目录联接，避免递归进入其它位置。
function Remove-CleanupPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "清理路径是链接，请先核实实际数据位置：$Path"
        }
        Write-Host "清理：$Path"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}
# 停止 Docker 与 WSL 写入，归档当前用户虚拟磁盘、集群与项目配置。
function Backup-CleanupData {
    param([string]$ProjectRoot, [string[]]$DataPaths, [string]$Mode)
    if ($Mode -ne 'backup') { return }
    foreach ($fileName in @('settings-store.json','settings.json')) {
        $settingsPath = Join-Path $env:APPDATA ('Docker\' + $fileName)
        if (Test-Path -LiteralPath $settingsPath) {
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            if ($settings.dataFolder) {
                $standardDirectory = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Docker')) + '\'
                $actualDirectory = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($settings.dataFolder)) + '\'
                if (-not $actualDirectory.StartsWith($standardDirectory, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "自定义 Docker 数据目录未纳入标准备份：$actualDirectory；停止卸载。"
                }
            }
        }
    }
    $profileRoot = Join-Path $env:USERPROFILE '.minikube\profiles'
    if (Test-Path -LiteralPath $profileRoot) {
        foreach ($profileFile in @(Get-ChildItem -LiteralPath $profileRoot -Filter 'config.json' -Recurse -File)) {
            $profile = Get-Content -LiteralPath $profileFile.FullName -Raw | ConvertFrom-Json
            if ($profile.Driver -ne 'docker') { throw "非 Docker 驱动需要专用备份：$($profileFile.FullName)" }
        }
    }
    $backupDirectory = Join-Path $env:USERPROFILE ('RepairMarketplaceBackups\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
    New-Item -ItemType Directory -Path $backupDirectory -ErrorAction Stop | Out-Null
    if (Get-Process -Name 'com.docker.backend' -ErrorAction SilentlyContinue) {
        $dockerCli = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
            (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe')
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $dockerCli) { throw '请先从系统托盘正常退出 Docker Desktop，再重试备份。' }
        & $dockerCli desktop stop
        Assert-CleanupExit '正常退出 Docker Desktop（旧版请从系统托盘退出后重试）'
    }
    $service = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Stopped') { Stop-Service $service -ErrorAction Stop }
    if (Get-Process -Name 'com.docker.backend' -ErrorAction SilentlyContinue) { throw 'Docker 后台仍在写入，已停止备份和卸载。' }
    # 旧版 Docker 的 WSL 虚拟磁盘可能存放在自定义 BasePath，单独导出避免漏备份。
    $registryRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    if (Test-Path $registryRoot) {
        $dockerDistributions = @(Get-ChildItem $registryRoot | Get-ItemProperty | Where-Object { $_.DistributionName -in @('docker-desktop','docker-desktop-data') })
        if ($dockerDistributions.Count -gt 0) {
            & wsl.exe --shutdown
            Assert-CleanupExit '停止 WSL'
        }
        foreach ($distribution in $dockerDistributions) {
            $exportPath = Join-Path $backupDirectory ($distribution.DistributionName + '.tar')
            & wsl.exe --export $distribution.DistributionName $exportPath
            Assert-CleanupExit "导出 $($distribution.DistributionName)"
            & tar.exe -tf $exportPath *> $null
            Assert-CleanupExit '验证 WSL 导出'
            "WSL 导出`t$($distribution.DistributionName).tar" | Add-Content -LiteralPath (Join-Path $backupDirectory 'restore-paths.txt') -Encoding UTF8
        }
        if ($dockerDistributions.Count -gt 0) {
            & wsl.exe --shutdown
            Assert-CleanupExit '导出后停止 WSL'
        }
    }
    $archiveNumber = 0
    foreach ($dataPath in $DataPaths) {
        if (-not (Test-Path -LiteralPath $dataPath)) { continue }
        $item = Get-Item -LiteralPath $dataPath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "备份路径是链接，请先核实：$dataPath" }
        $archiveNumber++
        $archive = Join-Path $backupDirectory "$archiveNumber.tar"
        & tar.exe -cpf $archive -C (Split-Path $dataPath -Parent) (Split-Path $dataPath -Leaf)
        Assert-CleanupExit "备份 $dataPath"
        & tar.exe -tf $archive *> $null
        Assert-CleanupExit "验证 $archive"
        "$archiveNumber.tar`t$dataPath" | Add-Content -LiteralPath (Join-Path $backupDirectory 'restore-paths.txt') -Encoding UTF8
    }
    Write-Host "数据归档已验证：$backupDirectory；恢复时需安装兼容版本并停服按 restore-paths.txt 还原。"
}
# 删除当前用户的所有 Minikube profiles，再移除部署入口安装的工具。
function Remove-MinikubeRuntime {
    $binary = Join-Path $env:LOCALAPPDATA 'Programs\Minikube\minikube.exe'
    $profiles = Join-Path $env:USERPROFILE '.minikube\profiles'
    if (Test-Path -LiteralPath $profiles) {
        if (-not (Test-Path -LiteralPath $binary)) {
            throw 'Minikube 数据存在但标准工具缺失，请恢复工具后重试。'
        }
        Invoke-DeploymentCommand -Command $binary -Arguments @('delete','--all','--purge')
        if ($script:DeploymentCommandExitCode -ne 0) { throw '删除全部本地 Minikube profiles 失败。' }
    }
    Remove-CleanupPath (Join-Path $env:USERPROFILE '.minikube')
    Remove-CleanupPath (Join-Path $env:LOCALAPPDATA 'Programs\Minikube')
}
# 用官方卸载器移除 per-user / all-user Docker Desktop 安装。
function Remove-DockerDesktopRuntime {
    $directories = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop'),
        (Join-Path $env:ProgramFiles 'Docker\Docker')
    )
    foreach ($directory in $directories) {
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        $installer = Join-Path $directory 'Docker Desktop Installer.exe'
        if (-not (Test-Path -LiteralPath $installer)) { throw "官方卸载器缺失：$installer" }
        $process = Start-Process -FilePath $installer -ArgumentList 'uninstall' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Docker 卸载失败：$($process.ExitCode)" }
    }
}
# 清理 Docker 的 WSL 发行版；有独立 Linux 发行版时保留共享 WSL 并明确报告。
function Remove-DockerWslRuntime {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return }
    $registryRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    $distributions = @()
    if (Test-Path $registryRoot) {
        $distributions = @(Get-ChildItem $registryRoot | Get-ItemProperty | Where-Object { $_.DistributionName })
    }
    foreach ($distribution in $distributions) {
        if ($distribution.DistributionName -in @('docker-desktop','docker-desktop-data')) {
            & wsl.exe --unregister $distribution.DistributionName
            Assert-CleanupExit "删除 $($distribution.DistributionName)"
        }
    }
    $otherDistributions = @($distributions | Where-Object { $_.DistributionName -notin @('docker-desktop','docker-desktop-data') })
    if ($otherDistributions.Count -gt 0) {
        Write-Warning '保留独立 WSL 发行版及共享 WSL；以下发行版不是部署脚本创建的环境：'
        foreach ($retainedDistribution in $otherDistributions) {
            Write-Host "  - $($retainedDistribution.DistributionName)"
        }
        $script:SharedWslRetained = $true
        return
    }
    $wslPackages = @(Get-AppxPackage -Name '*WindowsSubsystemForLinux*')
    foreach ($package in $wslPackages) { Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop }
    # 新版 WSL 的 MSI 安装不一定出现在 Appx 清单中。
    $msiPackages = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -eq 'Windows Subsystem for Linux' -and $_.PSChildName -match '^\{[0-9A-Fa-f-]+\}$'
    })
    foreach ($package in $msiPackages) {
        $process = Start-Process msiexec.exe -ArgumentList @('/x', $package.PSChildName, '/passive', '/norestart') -Wait -PassThru
        if ($process.ExitCode -notin @(0,3010)) { throw "WSL MSI 卸载失败：$($process.ExitCode)" }
        if ($process.ExitCode -eq 3010) { $script:CleanupRestartRequired = $true }
    }
    foreach ($featureName in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction Stop
        if ($feature.State -eq 'Enabled') {
            $result = Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction Stop
            if ($result.RestartNeeded) { $script:CleanupRestartRequired = $true }
        }
    }
}
# 编排备份、官方卸载、残留清理及结果核验，异常返回非零状态。
function Start-RepairCleanup {
    param([string]$ProjectRoot)
    $ErrorActionPreference = 'Stop'
    $script:SharedWslRetained = $false
    $script:CleanupRestartRequired = $false
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw '请使用当前账户以管理员身份打开 PowerShell 再执行；不要切换到其它账户。'
    }
    foreach ($variableName in @('DOCKER_HOST','DOCKER_CONTEXT','MINIKUBE_HOME','KUBECONFIG')) {
        if ([Environment]::GetEnvironmentVariable($variableName)) { throw "请先取消自定义环境变量：$variableName" }
    }
    foreach ($cliDirectory in @((Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'), (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'))) {
        if (Test-Path (Join-Path $cliDirectory 'docker.exe')) { $env:Path = "$cliDirectory;$env:Path"; break }
    }
    Select-LocalDockerTarget
    $dataPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Docker'),
        (Join-Path $env:APPDATA 'Docker'),
        (Join-Path $env:APPDATA 'Docker Desktop'),
        (Join-Path $env:ProgramData 'Docker'),
        (Join-Path $env:ProgramData 'DockerDesktop'),
        (Join-Path $env:USERPROFILE '.docker'),
        (Join-Path $env:USERPROFILE '.minikube'),
        (Join-Path $env:USERPROFILE '.kube'),
        (Join-Path $ProjectRoot 'Deployment\Docker\Shared\.env')
    )
    Write-Host '将卸载 Docker Desktop、全部 Minikube profiles、Docker 专用 WSL 环境。两个部署路线都会受影响。'
    Write-Host '数据范围包含其它容器项目；独立 Ubuntu 等 WSL 发行版和远程 Kubernetes 配置保留。'
    Write-Host '1、先备份再卸载（默认）；2、永久删除容器和集群数据。'
    $selection = Read-Host '请选择 [1/2]'
    switch ($selection) {
        '' { $mode = 'backup' }
        '1' { $mode = 'backup' }
        '2' { $mode = 'delete' }
        default { throw '无效选项，已取消。' }
    }
    if ($mode -eq 'backup' -and -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw '系统 tar.exe 不可用，无法备份。' }
    Write-Host "数据策略：$mode；备份写入当前用户 RepairMarketplaceBackups 目录。"
    if ((Read-Host '输入 YES 执行整套反安装，其它输入取消') -cne 'YES') { Write-Host '已取消。'; return }
    $logPath = Join-Path $env:TEMP ('repair-uninstall-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID + '.log')
    Start-Transcript -LiteralPath $logPath | Out-Null
    try {
        Backup-CleanupData -ProjectRoot $ProjectRoot -DataPaths $dataPaths -Mode $mode
        # 备份后重新启动已安装的 Desktop，让 Minikube 官方删除器正常清理虚拟机。
        if (Test-Path (Join-Path $env:USERPROFILE '.minikube\profiles')) {
            $desktop = @((Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'), (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')) | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $desktop) { throw '集群仍存在，但 Docker Desktop 缺失；请修复后重试。' }
            $env:Path = (Join-Path (Split-Path $desktop) 'resources\bin') + ';' + $env:Path
            Start-Process -FilePath $desktop
            $ready = $false
            for ($attempt = 0; $attempt -lt 60; $attempt++) {
                Invoke-DeploymentCommand -Command docker -Arguments @('info') *> $null
                if ($script:DeploymentCommandExitCode -eq 0) { $ready = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $ready) { throw 'Docker 未就绪，已停止清场。' }
        }
        Remove-MinikubeRuntime
        Remove-DockerDesktopRuntime
        Remove-DockerWslRuntime
        foreach ($dataPath in $dataPaths) {
            if ($dataPath -eq (Join-Path $env:USERPROFILE '.kube')) { continue }
            Remove-CleanupPath $dataPath
        }
        foreach ($directory in @((Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop'), (Join-Path $env:ProgramFiles 'Docker'))) {
            Remove-CleanupPath $directory
        }
        Remove-CleanupPath (Join-Path $env:TEMP 'DockerDesktopInstaller.exe')
        if (Get-Service 'com.docker.service' -ErrorAction SilentlyContinue) { throw 'Docker 服务仍残留，清场未完成。' }
        if ((Get-Command docker -ErrorAction SilentlyContinue) -or (Get-Command minikube -ErrorAction SilentlyContinue)) {
            throw 'PATH 中仍有其它安装来源的 Docker / Minikube，请用对应安装器清理后重试。'
        }
        if ($script:SharedWslRetained) { Write-Host '容器部署环境已移除；独立发行版使用的共享 WSL 已保留。' }
        elseif ($script:CleanupRestartRequired) { Write-Host '卸载步骤完成，需要重启 Windows 才能完成系统组件清理；不会自动重启。' }
        else { Write-Host '标准部署环境已清理。' }
        Write-Host "审计日志：$logPath"
    } finally {
        Stop-Transcript | Out-Null
    }
}
