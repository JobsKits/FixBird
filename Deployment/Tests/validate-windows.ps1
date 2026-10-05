# 脚本自述：仅解析 PS1 与运行函数替身，不调用 Windows 安装器、Docker daemon 或集群。
$ErrorActionPreference = 'Stop'
$auditRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $auditRoot 'Deployment\Kubernetes\Shared\deploy-windows.ps1')

# 判断应失败的调用确实被拒绝。
function Assert-Rejected {
    param([scriptblock]$Action)
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw '应被拒绝的测试调用通过。' }
}
# 假 Docker 只提供目标元数据，禁止任何真实命令执行。
function docker {
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'context' -and $args[1] -eq 'show') { return 'fixture-context' }
    if ($args[0] -eq 'context' -and $args[1] -eq 'inspect') { return $script:MockDockerEndpoint }
    $script:MockCommandArguments = @($args)
}
# 假 Minikube 捕获显式 profile / kubectl context，不访问集群。
function minikube { $global:LASTEXITCODE = 0; $script:MockCommandArguments = @($args) }
$savedEnvironment = @{}
try {
    foreach ($key in @('DOCKER_HOST','DOCKER_CONTEXT','BUILDX_BUILDER','BUILDKIT_HOST')) {
        $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $null, 'Process')
    }
    Initialize-DeploymentComponents -ProjectRoot $auditRoot
    $script:MockDockerEndpoint = 'npipe:////./pipe/dockerDesktopLinuxEngine'
    Select-LocalDockerTarget
    Invoke-DeploymentCommand -Command docker -Arguments @('compose','version')
    if ($script:MockCommandArguments[0] -ne '--host' -or $script:MockCommandArguments[1] -ne $script:MockDockerEndpoint) { throw '命令没有固定本机 pipe。' }
    Invoke-DeploymentCommand -Command minikube -Arguments @('kubectl','--','get','pods')
    if ($script:MockCommandArguments[0] -ne '--profile=minikube' -or $script:MockCommandArguments[-1] -ne '--context=minikube') { throw 'Minikube 没有固定 profile / context。' }
    Assert-MinikubeProfileMetadata -Profile ([pscustomobject]@{ Driver='docker'; Nodes=@([pscustomobject]@{Name='minikube'}) })
    Assert-Rejected { Assert-MinikubeProfileMetadata -Profile ([pscustomobject]@{ Driver='docker'; Nodes=@([pscustomobject]@{Name='minikube'},[pscustomobject]@{Name='worker'}) }) }
    Assert-Rejected { Assert-MinikubeProfileMetadata -Profile ([pscustomobject]@{ Driver='hyperv'; Nodes=@([pscustomobject]@{Name='minikube'}) }) }
    Assert-Rejected { Assert-MinikubeProfileMetadata -Profile ([pscustomobject]@{ Driver='docker'; Nodes=@() }) }
    $script:MockDockerEndpoint = 'ssh://fixture.invalid'
    Assert-Rejected { Select-LocalDockerTarget }
    $env:DOCKER_HOST = 'tcp://127.0.0.1:2375'
    Assert-Rejected { Select-LocalDockerTarget }
    $env:DOCKER_HOST = $null
    $env:BUILDX_BUILDER = 'remote-fixture'
    Assert-Rejected { Select-LocalDockerTarget }
    $env:BUILDX_BUILDER = $null
    foreach ($directory in @('Deployment','unDeployment')) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $auditRoot $directory) -Recurse -Filter '*.ps1') {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            if ($bytes.Length -lt 3 -or $bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) { throw "PS1 缺少 UTF-8 BOM：$($file.FullName)" }
            $tokens = $null
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            if (@($parseErrors).Count) { throw "PS1 解析失败：$($file.FullName)" }
        }
    }
    Write-Host 'PASS：PS1 BOM/Parser、本机 pipe 与 Minikube profile/context、远端/构建器/多节点拒绝（函数替身）。'
} finally {
    foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnvironment[$key], 'Process') }
}
