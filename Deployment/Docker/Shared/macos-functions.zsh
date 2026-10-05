# Shared macOS bootstrap helpers for Docker Desktop and Compose.

# Write deployment messages to the terminal and the run log.
# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
log_message() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

# Print a concise description before the installer changes the host.
show_macos_intro() {
  printf '\n啄木鸟维修平台 · %s 一键部署\n' "$DEPLOYMENT_NAME" | jobs_intro_style title
  printf '脚本入口：%s\n' "$SCRIPT_PATH" | jobs_intro_style body
  printf '系统：macOS；架构：%s\n' "$MAC_CPU_ARCH" | jobs_intro_style body
  if [[ "$DEPLOYMENT_NAME" == "kubernetes" ]]; then
    printf '范围：按需准备 Docker Desktop 与 Minikube 单节点集群，再部署 Go API 和 TiDB。\n' | jobs_intro_style body
    printf '影响：可能安装 Docker Desktop / Minikube，并在本机创建 Kubernetes 工作负载。\n' | jobs_intro_style body
  else
    printf '范围：按需准备容器环境，每次重建当前源码并部署 Go API 与 TiDB。\n' | jobs_intro_style body
    printf '影响：可能安装 Docker Desktop；项目部署配置会保存在 Deployment/Docker/Shared。\n' | jobs_intro_style body
  fi
  printf '网络：检测到系统 HTTP/HTTPS 代理时，另行等待回车确认后自动配置并重启 Docker Desktop。\n' | jobs_intro_style body
  printf '取消方式：按 Ctrl+C 取消；运行日志写入 ~/Library/Logs/RepairMarketplace。\n\n' | jobs_intro_style body
  if [[ ! -t 0 ]]; then
    printf '当前没有可交互输入，无法确认部署；请在 Terminal 中运行此入口。\n' >&2
    return 1
  fi
  local confirmation=""
  if ! read -r "confirmation?已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消："; then
    printf '未收到确认输入，已取消部署。\n' >&2
    return 1
  fi
}

# Initialize a per-user log after the intro has been printed.
initialize_macos_log() {
  local log_directory="$HOME/Library/Logs/RepairMarketplace"
  mkdir -p "$log_directory"
  LOG_FILE="$log_directory/$DEPLOYMENT_NAME.log"
  touch "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

# Detect Apple Silicon or Intel and normalize the download architecture.
detect_macos_arch() {
  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then
    MAC_CPU_ARCH=arm64
    return 0
  fi
  case "$(uname -m)" in
    arm64) MAC_CPU_ARCH="arm64" ;;
    x86_64) MAC_CPU_ARCH="amd64" ;;
    *)
      printf '不支持的 Mac CPU 架构：%s\n' "$(uname -m)" >&2
      return 1
      ;;
  esac
}

# Wait for the Docker Desktop daemon to become ready.
wait_for_docker_desktop() {
  local attempt
  for attempt in {1..150}; do
    if run_docker_with_proxy info >/dev/null 2>&1; then
      log_message "Docker Desktop 已就绪。"
      return 0
    fi
    sleep 2
  done
  log_message "Docker Desktop 尚未就绪。首次启动时请在应用窗口接受 Docker 条款后重试。"
  return 1
}

# Download and install the Docker Desktop image matching this Mac's chip.
install_docker_desktop() {
  local temporary_directory="$(mktemp -d -t repair-marketplace-docker)"
  local image_path="$temporary_directory/Docker.dmg"
  local mount_path="$temporary_directory/volume"
  local component_key="DOCKER_DESKTOP_MAC_${(U)MAC_CPU_ARCH}"
  local download_url="$(deployment_component "${component_key}_URL")"
  local attempt
  local downloaded=0
  local local_image="${DOCKER_DESKTOP_DMG:-}"

  if [[ -z "$local_image" ]]; then
    for attempt in {1..3}; do
      log_message "按 $MAC_CPU_ARCH 架构下载 Docker Desktop（$attempt/3）。"
      if curl --fail --location --show-error --http1.1 \
        --connect-timeout 15 --max-time 1800 --speed-time 30 --speed-limit 1024 \
        "$download_url" --output "$image_path"; then
        downloaded=1
        break
      fi
      log_message "官方下载安装包失败；请检查网络、代理或防火墙。"
      [[ "$attempt" -eq 3 ]] || sleep 2
    done
    if [[ "$downloaded" -eq 0 ]]; then
      log_message "自动下载三次均失败。官方安装页：https://docs.docker.com/desktop/setup/install/mac-install/"
      log_message "可在浏览器下载清单固定的 $(deployment_component DOCKER_DESKTOP_VERSION) / $MAC_CPU_ARCH 安装包，再拖入下方；其它版本会被摘要校验拒绝。直接回车取消。"
      log_message "固定官方下载地址：$download_url"
      if ! read -r "local_image?本地官方 Docker.dmg 路径："; then
        local_image=""
      fi
    fi
  fi
  if [[ "$downloaded" -eq 0 ]]; then
    rm -f "$image_path"
    rmdir "$temporary_directory"
    local_image="${local_image%$'\r'}"
    local_image="${local_image#\"}"
    local_image="${local_image%\"}"
    local_image="${local_image#\'}"
    local_image="${local_image%\'}"
    # Finder 拖入的路径可能使用反斜线转义空格。
    local_image="${(Q)local_image}"
    if [[ -z "$local_image" || ! -f "$local_image" ]]; then
      log_message "未提供有效安装包，部署已停止。日志：$LOG_FILE"
      return 1
    fi
    image_path="${local_image:A}"
    temporary_directory="$(mktemp -d -t repair-marketplace-docker)"
    mount_path="$temporary_directory/volume"
  fi
  if ! verify_deployment_download "$image_path" "$(deployment_component "${component_key}_SHA256")" || ! hdiutil verify "$image_path"; then
    log_message "DMG 校验失败，未执行安装：$image_path"
    [[ "$downloaded" -eq 0 ]] || rm -f "$image_path"
    rmdir "$temporary_directory"
    return 1
  fi
  mkdir -p "$mount_path"
  if ! hdiutil attach "$image_path" -mountpoint "$mount_path" -nobrowse -quiet; then
    log_message "无法挂载 Docker 安装包：$image_path"
    [[ "$downloaded" -eq 0 ]] || rm -f "$image_path"
    rmdir "$mount_path" "$temporary_directory"
    return 1
  fi
  local install_result=0
  local docker_team
  docker_team="$(codesign -dv --verbose=4 "$mount_path/Docker.app" 2>&1 | awk -F= '$1 == "TeamIdentifier" {print $2}')"
  if ! codesign --verify --deep --strict "$mount_path/Docker.app" || [[ "$docker_team" != "$(deployment_component DOCKER_MAC_TEAM_ID)" ]]; then
    log_message "Docker 开发者签名校验失败，未执行安装。"
    install_result=1
  elif [[ ! -x "$mount_path/Docker.app/Contents/MacOS/install" ]]; then
    log_message "安装包中没有 Docker Desktop 安装程序。"
    install_result=1
  elif ! sudo "$mount_path/Docker.app/Contents/MacOS/install" --user="$USER"; then
    log_message "Docker Desktop 安装失败。"
    install_result=1
  fi
  if ! hdiutil detach "$mount_path" -quiet; then
    log_message "安装镜像未能卸载，保留临时目录：$temporary_directory"
    return 1
  fi
  [[ "$downloaded" -eq 0 ]] || rm -f "$image_path"
  rmdir "$mount_path" "$temporary_directory"
  return "$install_result"
}

# Start Docker Desktop and install it only when no working engine is available.
ensure_docker_desktop() {
  detect_macos_arch
  if [[ -x /Applications/Docker.app/Contents/Resources/bin/docker ]]; then
    PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
    export PATH
  fi
  select_local_docker_target macos
  if ! run_docker_with_proxy info >/dev/null 2>&1; then
    if [[ ! -d /Applications/Docker.app ]]; then
      install_docker_desktop
    fi
    PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
    export PATH
    open -a Docker
    select_local_docker_target macos
    wait_for_docker_desktop
  fi
  validate_docker_server "$MAC_CPU_ARCH"
  if ! run_docker_with_proxy compose version >/dev/null 2>&1; then
    log_message "Docker Compose 插件不可用，请更新 Docker Desktop 后重试。"
    return 1
  fi
  configure_docker_desktop_proxy
}

# Reuse the macOS proxy through Docker's supported installer flags after consent.
configure_docker_desktop_proxy() {
  local system_proxy="$(scutil --proxy)"
  local proxy_kind proxy_enabled proxy_host proxy_port
  local http_proxy="" https_proxy=""
  for proxy_kind in HTTP HTTPS; do
    proxy_enabled="$(printf '%s\n' "$system_proxy" | awk -v key="${proxy_kind}Enable" '$1 == key {print $3; exit}')"
    proxy_host="$(printf '%s\n' "$system_proxy" | awk -v key="${proxy_kind}Proxy" '$1 == key {print $3; exit}')"
    proxy_port="$(printf '%s\n' "$system_proxy" | awk -v key="${proxy_kind}Port" '$1 == key {print $3; exit}')"
    [[ "$proxy_enabled" == 1 ]] || continue
    if [[ -z "$proxy_host" || "$proxy_host" == *[^a-zA-Z0-9.:-]* || "$proxy_port" != <1-65535> ]]; then
      log_message "系统 $proxy_kind 代理地址无效，未修改 Docker Desktop。"
      return 1
    fi
    [[ "$proxy_host" != *:* ]] || proxy_host="[$proxy_host]"
    if [[ "$proxy_kind" == HTTP ]]; then
      http_proxy="http://$proxy_host:$proxy_port"
    else
      https_proxy="http://$proxy_host:$proxy_port"
    fi
  done
  if [[ -z "$http_proxy$https_proxy" ]]; then
    log_message "未检测到启用的系统 HTTP/HTTPS 代理，保留 Docker Desktop 当前网络配置。"
    return 0
  fi
  http_proxy="${http_proxy:-$https_proxy}"
  https_proxy="${https_proxy:-$http_proxy}"
  local installer="/Applications/Docker.app/Contents/MacOS/install"
  if [[ ! -x "$installer" ]] || ! "$installer" --help 2>&1 | /usr/bin/grep -q -- '--override-proxy-https'; then
    log_message "当前 Docker Desktop 不支持自动代理配置，请更新后重试。"
    return 1
  fi
  if ! docker desktop stop --help >/dev/null 2>&1; then
    log_message "当前 Docker Desktop 缺少停止命令，请更新后重试。"
    return 1
  fi
  local bypass="localhost,127.0.0.1,::1,*.local,*.internal"
  local exception
  for exception in ${(f)"$(printf '%s\n' "$system_proxy" | awk '/ExceptionsList :/ {inside=1; next} inside && /}/ {exit} inside && $2 == ":" {print $3}')"}; do
    [[ -z "$exception" ]] || bypass+=",$exception"
  done
  local settings_file="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
  local proxy_unchanged=0
  if [[ -f "$settings_file" ]] && \
    [[ "$(plutil -extract ProxyHTTPMode raw -o - "$settings_file" 2>/dev/null || true)" == manual && \
       "$(plutil -extract OverrideProxyHTTP raw -o - "$settings_file" 2>/dev/null || true)" == "$http_proxy" && \
       "$(plutil -extract OverrideProxyHTTPS raw -o - "$settings_file" 2>/dev/null || true)" == "$https_proxy" && \
       "$(plutil -extract OverrideProxyExclude raw -o - "$settings_file" 2>/dev/null || true)" == "$bypass" ]]; then
    proxy_unchanged=1
  fi
  printf '\n即将自动配置 Docker Desktop 代理：\nHTTP：%s\nHTTPS：%s\n绕过：\n' "$http_proxy" "$https_proxy"
  local -aU bypass_items=("${(@s:,:)bypass}")
  for exception in "${bypass_items[@]}"; do
    printf '  - %s\n' "$exception"
  done
  if [[ "$proxy_unchanged" -eq 1 ]]; then
    printf '影响：当前 Desktop 代理配置相同，复用现有设置，无需重启或管理员密码；代理软件需保持运行。\n'
  else
    printf '影响：修改本用户 Docker Desktop 全局代理，备份设置后停止并重新启动 Docker Desktop；其它容器项目也会中断。\n'
    printf '配置通过 Docker 官方安装器完成，可能需要输入管理员密码；代理软件需保持运行。\n'
  fi
  printf '同时为本脚本的 Docker 构建命令设置临时代理，覆盖本机 Buildx 客户端的镜像认证请求。\n'
  local confirmation=""
  [[ -t 0 ]] || { log_message "没有交互输入，未修改代理。"; return 1; }
  while true; do
    if ! read -r "confirmation?按回车确认使用上述代理（配置变化时重启）；按 Ctrl+C 取消部署："; then
      return 1
    fi
    [[ -z "$confirmation" ]] && break
    printf '请直接按回车确认，或按 Ctrl+C 取消。\n'
  done
  # Avoid stopping other projects if the selected proxy cannot reach the registry.
  local response_code endpoint expected_code
  for endpoint in 'https://registry-1.docker.io/v2/' 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull'; do
    expected_code=200
    [[ "$endpoint" != 'https://registry-1.docker.io/v2/' ]] || expected_code=401
    response_code="$(curl --silent --output /dev/null --write-out '%{http_code}' \
      --noproxy '' --proxy "$https_proxy" --connect-timeout 10 --max-time 20 \
      "$endpoint")" || {
      log_message "系统代理无法连接 ${endpoint}，未修改配置；请确认代理软件已启动及其网络出口可用。"
      return 1
    }
    if [[ "$response_code" != "$expected_code" ]]; then
      log_message "代理访问 $endpoint 返回 HTTP $response_code（预期 $expected_code），未修改配置。"
      return 1
    fi
  done
  if [[ "$proxy_unchanged" -eq 1 ]]; then
    DEPLOYMENT_HTTP_PROXY="$http_proxy"
    DEPLOYMENT_HTTPS_PROXY="$https_proxy"
    log_message "已复用 Desktop 代理；后续 Docker 命令同时使用临时客户端代理，继续部署。"
    return 0
  fi
  local backup_directory="$(mktemp -d "$HOME/Library/Logs/RepairMarketplace/docker-proxy-backup.XXXXXX")"
  [[ -d "$backup_directory" ]] || { log_message "无法创建设置备份目录，未修改代理。"; return 1; }
  docker desktop stop --timeout 60 || { log_message "停止 Docker Desktop 失败，未修改代理。"; return 1; }
  if [[ -f "$settings_file" ]]; then
    if ! cp -p "$settings_file" "$backup_directory/settings-store.json"; then
      open -a Docker
      log_message "备份失败，未修改代理；已请求重新启动 Docker Desktop。"
      return 1
    fi
    log_message "原设置备份：$backup_directory/settings-store.json"
  fi
  local configuration_result=0
  if ! sudo "$installer" --user="$USER" --proxy-http-mode=manual \
    --override-proxy-http="$http_proxy" --override-proxy-https="$https_proxy" \
    --override-proxy-exclude="$bypass" --override-proxy-pac='' --override-proxy-embedded-pac=''; then
    configuration_result=1
    log_message "官方安装器配置代理失败；设置备份目录：$backup_directory"
  fi
  open -a Docker
  wait_for_docker_desktop || return 1
  [[ "$configuration_result" -eq 0 ]] || return 1
  DEPLOYMENT_HTTP_PROXY="$http_proxy"
  DEPLOYMENT_HTTPS_PROXY="$https_proxy"
  log_message "Docker Desktop 代理已配置；后续 Docker 命令同时使用临时客户端代理，继续部署。"
}

# Scope host authentication proxies to Docker commands without changing shell profiles.
run_docker_with_proxy() {
  [[ -n "${DEPLOYMENT_DOCKER_HOST:-}" ]] || { log_message "尚未固定本机 Docker 目标，停止执行。"; return 1; }
  if [[ -n "${DEPLOYMENT_HTTP_PROXY:-}" && -n "${DEPLOYMENT_HTTPS_PROXY:-}" ]]; then
    env -u DOCKER_HOST -u DOCKER_CONTEXT HTTP_PROXY="$DEPLOYMENT_HTTP_PROXY" HTTPS_PROXY="$DEPLOYMENT_HTTPS_PROXY" \
      http_proxy="$DEPLOYMENT_HTTP_PROXY" https_proxy="$DEPLOYMENT_HTTPS_PROXY" \
      NO_PROXY='localhost,127.0.0.1,::1' no_proxy='localhost,127.0.0.1,::1' \
      docker --host "$DEPLOYMENT_DOCKER_HOST" "$@"
  else
    env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$DEPLOYMENT_DOCKER_HOST" "$@"
  fi
}
# 共用 daemon 校验入口，始终使用已经固定的本机 socket。
docker_command() {
  run_docker_with_proxy "$@"
}
# 加载版本与下载校验模块，确认后再进入环境准备。
load_macos_components() {
  source "$PROJECT_ROOT/Deployment/Shared/components.sh"
  initialize_deployment_components "$PROJECT_ROOT"
}

# Create the shared default Compose configuration without overwriting user settings.
prepare_compose_environment() {
  local shared_directory="$PROJECT_ROOT/Deployment/Docker/Shared"
  if [[ ! -f "$shared_directory/.env" ]]; then
    cp "$shared_directory/.env.example" "$shared_directory/.env"
    log_message "已创建默认部署配置：Deployment/Docker/Shared/.env"
  fi
}

# Deploy the Go API and TiDB stack using Docker Compose.
deploy_compose_stack() {
  local shared_directory="$PROJECT_ROOT/Deployment/Docker/Shared"
  local environment_file="$shared_directory/.env"
  local api_port
  local attempt
  local lan_address
  local -a compose_files
  compose_files=(--file "$shared_directory/compose.yaml")
  lan_address="$(awk -F= '$1 == "API_LAN_BIND_ADDRESS" { gsub(/[[:space:]\r]/, "", $2); print $2; exit }' "$environment_file")"
  if [[ -n "$lan_address" ]]; then
    compose_files+=(--file "$shared_directory/compose.lan.yaml")
  fi
  log_message "每次部署都会重新构建当前源码，再更新 API 容器；数据库与图片数据卷保留。"

  api_port="$(awk -F= '$1 == "API_PORT" { gsub(/[[:space:]\r]/, "", $2); print $2; exit }' "$environment_file")"
  if [[ -z "$api_port" ]]; then
    api_port=8080
  fi
  if [[ -n "$lan_address" ]]; then
    log_message "保留真机联调入口：http://$lan_address:$api_port；同时保留本机回环入口。"
  fi
  if ! run_docker_with_proxy compose \
    --project-directory "$shared_directory" \
    --project-name repair-marketplace \
    "${compose_files[@]}" \
    --env-file "$environment_file" \
    build --builder default --build-arg "GO_VERSION=$(deployment_component GO_VERSION)" --build-arg "APP_BUILD_VERSION=demo-$(date -u +%Y%m%dT%H%M%SZ)"; then
    log_message "Compose 构建或启动失败，请根据上方错误定位原因。"
    log_message "若出现 auth.docker.io / registry-1.docker.io 的超时，请确认系统代理软件及网络出口可用，再重跑入口并回车确认自动配置代理。"
    log_message "未启用系统 HTTP/HTTPS 代理时，脚本会保留 Docker Desktop 当前配置；Terminal 的代理设置不一定覆盖构建引擎。"
    log_message "同时检查 DNS 解析及网络出口。日志：$LOG_FILE"
    return 1
  fi
  run_docker_with_proxy compose --project-directory "$shared_directory" --project-name repair-marketplace "${compose_files[@]}" --env-file "$environment_file" up --detach --no-build
  for attempt in {1..90}; do
    if curl --fail --silent --noproxy '*' --connect-timeout 2 --max-time 3 "http://127.0.0.1:$api_port/readyz" >/dev/null; then
      log_message "部署完成："
      log_message "  Web 管理后台：http://127.0.0.1:$api_port/admin/"
      log_message "  管理员登录：默认账号由程序自动创建；已有账号密码不会被部署覆盖。"
      log_message "  API 健康检查：http://127.0.0.1:$api_port/healthz"
      open "http://127.0.0.1:$api_port/admin/"
      return 0
    fi
    sleep 2
  done
  log_message "服务尚未通过健康检查，请查看 Docker Desktop 日志或运行 docker compose logs。"
  run_docker_with_proxy compose --project-directory "$shared_directory" --project-name repair-marketplace "${compose_files[@]}" logs --tail=100
  return 1
}
