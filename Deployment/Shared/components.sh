# 共享组件清单与下载校验；仅定义函数，不安装软件或修改用户环境。
# 初始化当前工程的受控版本清单路径。
initialize_deployment_components() {
  DEPLOYMENT_COMPONENTS_FILE="$1/Deployment/Shared/components.env"
  [[ -r "$DEPLOYMENT_COMPONENTS_FILE" ]] || { printf '找不到组件版本清单：%s\n' "$DEPLOYMENT_COMPONENTS_FILE" >&2; return 1; }
}
# 按精确键读取清单，不把配置内容当成 Shell 执行。
deployment_component() {
  local component_value
  component_value="$(awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit }' "$DEPLOYMENT_COMPONENTS_FILE")"
  [[ -n "$component_value" ]] || { printf '组件清单缺少字段：%s\n' "$1" >&2; return 1; }
  printf '%s\n' "$component_value"
}
# 用系统现有工具计算 SHA256，不额外安装运行时。
deployment_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
# 校验完整下载，失败时不得执行或替换已有软件。
verify_deployment_download() {
  local expected_sha="$2"
  [[ "$expected_sha" =~ ^[a-f0-9]{64}$ ]] || { printf '无效的预期 SHA256，停止下载文件执行。\n' >&2; return 1; }
  [[ "$(deployment_sha256 "$1")" == "$expected_sha" ]] || { printf 'SHA256 校验失败：%s；请核对官方发布物后更新组件清单。\n' "$1" >&2; return 1; }
}
# 读取固定下载来源与校验值，代理只作用于本次下载。
download_deployment_component() {
  local key="$1" destination="$2"
  local url expected_sha
  url="$(deployment_component "${key}_URL")" || return 1
  expected_sha="$(deployment_component "${key}_SHA256")" || return 1
  if [[ -n "${DEPLOYMENT_HTTPS_PROXY:-}" ]]; then
    curl --fail --location --show-error --connect-timeout 15 --max-time 1800 --retry 2 --proxy "$DEPLOYMENT_HTTPS_PROXY" "$url" --output "$destination" || return 1
  else
    curl --fail --location --show-error --connect-timeout 15 --max-time 1800 --retry 2 "$url" --output "$destination" || return 1
  fi
  verify_deployment_download "$destination" "$expected_sha"
}
# 拒绝远端 daemon，锁定后续命令使用的本机 socket；不更改全局 context。
select_local_docker_target() {
  local platform="$1" selected_context endpoint
  [[ -z "${DOCKER_HOST:-}" ]] || { printf '标准本机部署不接受 DOCKER_HOST 覆盖；请在当前终端取消该变量后重试。\n' >&2; return 1; }
  [[ -z "${BUILDX_BUILDER:-}${BUILDKIT_HOST:-}" ]] || { printf '标准本机部署不接受远端构建器环境覆盖，请取消 BUILDX_BUILDER / BUILDKIT_HOST 后重试。\n' >&2; return 1; }
  if ! command -v docker >/dev/null 2>&1; then
    [[ -z "${DOCKER_CONTEXT:-}" ]] || { printf 'Docker 尚未安装，不能验证 DOCKER_CONTEXT，已停止。\n' >&2; return 1; }
    DEPLOYMENT_DOCKER_HOST=''
    return 0
  fi
  selected_context="$(docker context show)" || return 1
  endpoint="$(docker context inspect "$selected_context" --format '{{.Endpoints.docker.Host}}')" || return 1
  case "$platform:$endpoint" in
    linux:unix:///var/run/docker.sock|linux:unix:///run/docker.sock|macos:unix:///var/run/docker.sock|"macos:unix://$HOME/.docker/run/docker.sock") ;;
    *) printf '拒绝非标准本机 Docker 目标：context=%s endpoint=%s\n请使用本机 Docker context 后重试；脚本不会切换全局 context。\n' "$selected_context" "$endpoint" >&2; return 1 ;;
  esac
  DEPLOYMENT_DOCKER_HOST="$endpoint"
  printf '已固定本机 Docker 目标：context=%s endpoint=%s\n' "$selected_context" "$endpoint"
}
# 校验容器运行平台与已检测的主机架构一致。
validate_docker_server() {
  local expected_arch="$1" server
  server="$(docker_command info --format '{{.OSType}}/{{.Architecture}}')" || return 1
  case "$server:$expected_arch" in
    linux/amd64:amd64|linux/x86_64:amd64|linux/arm64:arm64|linux/aarch64:arm64) ;;
    *) printf 'Docker daemon 平台与主机不一致：%s，预期 linux/%s。\n' "$server" "$expected_arch" >&2; return 1 ;;
  esac
}
