#!/usr/bin/env bash
# Shared Linux bootstrap helpers for the Docker deployment route.

# Write deployment messages to both the terminal and the run log.
log_message() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

# Explain the deployment scope before making host changes.
show_script_intro() {
  printf '\n啄木鸟维修平台 · Docker 一键部署\n'
  printf '脚本入口：%s\n' "$SCRIPT_PATH"
  printf '系统：%s %s；架构：%s\n' "$PRETTY_NAME" "$VERSION_ID" "$CPU_ARCH"
  printf '范围：按需安装 Docker Engine / Compose，每次重建当前源码并部署 Go API 与 TiDB。\n'
  printf '影响：安装系统软件包、启用 Docker 服务，并在项目内创建部署配置。\n'
  printf '日志：$HOME/.local/state/repair-platform/repair-platform-docker.log\n\n'
  if [[ ! -t 0 ]]; then
    printf '当前没有可交互输入，无法确认部署；请在交互式终端中运行此入口。\n' >&2
    return 1
  fi
  local confirmation=""
  if ! IFS= read -r -p '已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：' confirmation; then
    printf '未收到确认输入，已取消部署。\n' >&2
    return 1
  fi
}

# Initialize a per-user log after the intro has been printed.
initialize_log() {
  mkdir -p "$HOME/.local/state/repair-platform"
  LOG_FILE="$HOME/.local/state/repair-platform/repair-platform-docker.log"
  touch "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

# Detect and normalize the host CPU architecture for matching downloads.
detect_cpu_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) CPU_ARCH="amd64" ;;
    aarch64 | arm64) CPU_ARCH="arm64" ;;
    *)
      printf '不支持的 CPU 架构：%s\n' "$(uname -m)" >&2
      return 1
      ;;
  esac
}

# Read the operating-system identity provided by the distribution.
read_os_release() {
  if [[ ! -r /etc/os-release ]]; then
    printf '找不到 /etc/os-release，无法识别 Linux 发行版。\n' >&2
    return 1
  fi
  . /etc/os-release
  OS_ID="$ID"
  VERSION_ID="$VERSION_ID"
  PRETTY_NAME="$PRETTY_NAME"
}

# Validate the selected distribution entry against its declared support range.
validate_linux_platform() {
  local supported_id
  local id_matched=false
  for supported_id in $(printf '%s' "$EXPECTED_OS_IDS" | tr '|' ' '); do
    if [[ "$OS_ID" == "$supported_id" ]]; then
      id_matched=true
      break
    fi
  done
  if [[ "$id_matched" != true ]]; then
    log_message "当前系统 ID 为 '$OS_ID'，此入口只适用于："
    while IFS= read -r supported_id; do
      log_message "  - $supported_id"
    done < <(printf '%s\n' "$EXPECTED_OS_IDS" | tr '|' '\n')
    return 1
  fi
  if [[ ! "$VERSION_ID" =~ $SUPPORTED_VERSION_REGEX ]]; then
    log_message "当前版本为 '$VERSION_ID'，本入口未声明支持该版本。"
    return 1
  fi
  if [[ -n "$EXPECTED_NAME_FRAGMENT" && "$PRETTY_NAME" != *"$EXPECTED_NAME_FRAGMENT"* ]]; then
    log_message "当前系统名称不符合入口要求：${EXPECTED_NAME_FRAGMENT}。"
    return 1
  fi
  log_message "系统识别通过：$PRETTY_NAME ($OS_ID $VERSION_ID / $CPU_ARCH)。"
}

# Run a command with administrator privileges only when the current user needs them.
run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Install a downloader through the host package manager when none is present.
ensure_downloader() {
  if command -v curl >/dev/null 2>&1; then
    return 0
  fi
  log_message "未找到 curl / wget，正在通过系统包管理器安装 curl。"
  case "$OS_ID" in
    ubuntu | debian)
      run_as_root apt-get update
      run_as_root apt-get install -y curl ca-certificates
      ;;
    *)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y curl ca-certificates
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y curl ca-certificates
      elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper --non-interactive install curl ca-certificates
      else
        log_message "没有可识别的包管理器，无法安装下载工具。"
        return 1
      fi
      ;;
  esac
}

# Download a URL to a file using whichever downloader exists.
download_file() {
  local url="$1"
  local destination="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --connect-timeout 15 --max-time 1800 --retry 2 "$url" --output "$destination"
  else
    wget --quiet --timeout=30 --tries=3 -O "$destination" "$url"
  fi
}

# Install Docker Engine and Compose only when the current host lacks a working daemon.
install_docker_engine() {
  local install_script
  local temporary_directory

  if command -v docker >/dev/null 2>&1 && docker_command info >/dev/null 2>&1 && docker_command compose version >/dev/null 2>&1; then
    log_message "Docker Engine 与 Compose 已可用，跳过安装。"
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker_command info >/dev/null 2>&1; then
    ensure_downloader
    temporary_directory="$(mktemp -d)"
    install_compose_plugin "$temporary_directory"
    rm -rf "$temporary_directory"
    log_message "复用已运行的 Docker Engine，已补齐 Compose。"
    return 0
  fi

  ensure_downloader
  temporary_directory="$(mktemp -d)"
  install_script="$temporary_directory/install-docker.sh"
  log_message "下载 Docker 官方开发环境安装脚本。"
  download_deployment_component DOCKER_INSTALL "$install_script"
  if ! run_as_root sh "$install_script"; then
    log_message "官方便捷安装脚本未识别当前发行版，尝试系统包仓库。"
    install_native_docker_package
  fi

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    run_as_root service docker start
  else
    log_message "找不到 systemctl / service，无法启动 Docker daemon。"
    return 1
  fi

  select_local_docker_target linux
  install_compose_plugin "$temporary_directory"
  wait_for_docker
  rm -rf "$temporary_directory"
}

# Try the distribution package after the Docker convenience installer declines the OS.
install_native_docker_package() {
  local repository_url
  case "$OS_ID" in
    ubuntu | debian)
      run_as_root apt-get update
      run_as_root apt-get install -y docker.io
      ;;
    sles | opensuse-leap | opensuse)
      run_as_root zypper --non-interactive install docker
      ;;
    *)
      if command -v dnf >/dev/null 2>&1; then
        if [[ "$OS_ID" == fedora ]]; then
          repository_url="https://download.docker.com/linux/fedora/docker-ce.repo"
          if run_as_root dnf config-manager addrepo --from-repofile "$repository_url" && \
            run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; then
            return 0
          fi
          log_message "Docker CE 仓库不可用，尝试 Fedora 的兼容 Docker Engine 包。"
          run_as_root dnf install -y moby-engine
          return 0
        fi
        if ! run_as_root dnf install -y dnf-plugins-core; then
          log_message "无法安装 dnf 插件，尝试当前发行版维护的 docker 包。"
          run_as_root dnf install -y docker
          return 0
        fi
        if [[ "$OS_ID" == rhel ]]; then
          repository_url="https://download.docker.com/linux/rhel/docker-ce.repo"
        else
          repository_url="https://download.docker.com/linux/centos/docker-ce.repo"
        fi
        if run_as_root dnf config-manager --add-repo "$repository_url" && \
          run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; then
          return 0
        fi
        log_message "Docker CE 仓库不支持当前云发行版，尝试系统维护的 docker 包。"
        run_as_root dnf install -y docker
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y docker
      else
        log_message "没有适用于 '$OS_ID' 的自动 Docker 安装流程。"
        return 1
      fi
      ;;
  esac
}

# Install the Compose v2 CLI plugin if the package source did not provide it.
install_compose_plugin() {
  local temporary_directory="$1"
  local compose_arch
  local plugin_directory="/usr/local/lib/docker/cli-plugins"
  local plugin_file="$temporary_directory/docker-compose"

  if docker_command compose version >/dev/null 2>&1; then
    return 0
  fi
  case "$CPU_ARCH" in
    amd64) compose_arch="x86_64" ;;
    arm64) compose_arch="aarch64" ;;
  esac
  log_message "按 $CPU_ARCH 架构下载固定版本 Docker Compose 插件。"
  download_deployment_component "COMPOSE_LINUX_$(printf '%s' "$CPU_ARCH" | tr '[:lower:]' '[:upper:]')" "$plugin_file"
  run_as_root install -d -m 0755 "$plugin_directory"
  assert_plugin_owned_or_absent "$plugin_directory/docker-compose"
  run_as_root install -m 0755 "$plugin_file" "$plugin_directory/docker-compose"
  record_installed_plugin "$plugin_directory/docker-compose"
  docker_command compose version
}

# Install the architecture-matched official Buildx plugin only when unavailable.
ensure_buildx_plugin() {
  if docker_command buildx version >/dev/null 2>&1; then
    return 0
  fi
  local temporary_directory="$(mktemp -d)"
  local release_tag
  release_tag="$(deployment_component BUILDX_VERSION)"
  log_message "按 $CPU_ARCH 架构补齐 Docker Buildx ${release_tag}。"
  download_deployment_component "BUILDX_LINUX_$(printf '%s' "$CPU_ARCH" | tr '[:lower:]' '[:upper:]')" "$temporary_directory/docker-buildx"
  run_as_root install -d -m 0755 /usr/local/lib/docker/cli-plugins
  assert_plugin_owned_or_absent /usr/local/lib/docker/cli-plugins/docker-buildx
  run_as_root install -m 0755 "$temporary_directory/docker-buildx" /usr/local/lib/docker/cli-plugins/docker-buildx
  record_installed_plugin /usr/local/lib/docker/cli-plugins/docker-buildx
  rm -rf "$temporary_directory"
  docker_command buildx version
}

# 拒绝覆盖不是本项目安装的手工插件。
assert_plugin_owned_or_absent() {
  local plugin_path="$1" receipt=/var/lib/repair-marketplace-deployment/owned-plugins.tsv expected_sha
  [[ ! -L "$plugin_path" ]] || { log_message "插件路径是符号链接，不覆盖：$plugin_path"; return 1; }
  [[ ! -e "$plugin_path" ]] && return 0
  expected_sha="$(run_as_root awk -F '\t' -v path="$plugin_path" '$1 == path { hash=$2 } END { print hash }' "$receipt" 2>/dev/null || true)"
  [[ -n "$expected_sha" && "$(deployment_sha256 "$plugin_path")" == "$expected_sha" ]] || { log_message "手工插件归属不明或已被修改，不覆盖：$plugin_path"; return 1; }
}
# 记录本项目实际安装的插件内容摘要，供精确反安装使用。
record_installed_plugin() {
  local plugin_path="$1" plugin_sha
  plugin_sha="$(deployment_sha256 "$plugin_path")"
  run_as_root install -d -m 0755 /var/lib/repair-marketplace-deployment
  printf '%s\t%s\n' "$plugin_path" "$plugin_sha" | run_as_root tee -a /var/lib/repair-marketplace-deployment/owned-plugins.tsv >/dev/null
}
# Select an accessible Docker daemon, using sudo when the current user lacks socket access.
docker_command() {
  [[ -n "${DEPLOYMENT_DOCKER_HOST:-}" ]] || { printf '尚未固定本机 Docker 目标，停止执行。\n' >&2; return 1; }
  if env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$DEPLOYMENT_DOCKER_HOST" info >/dev/null 2>&1; then
    env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$DEPLOYMENT_DOCKER_HOST" "$@"
  else
    run_as_root env -u DOCKER_HOST -u DOCKER_CONTEXT \
      HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-}}" HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}" \
      http_proxy="${http_proxy:-${HTTP_PROXY:-}}" https_proxy="${https_proxy:-${HTTPS_PROXY:-}}" \
      NO_PROXY="${NO_PROXY:-${no_proxy:-localhost,127.0.0.1,::1}}" \
      no_proxy="${no_proxy:-${NO_PROXY:-localhost,127.0.0.1,::1}}" docker --host "$DEPLOYMENT_DOCKER_HOST" "$@"
  fi
}

# Start Docker and wait until the daemon accepts requests.
wait_for_docker() {
  local attempt
  for attempt in {1..60}; do
    if docker_command info >/dev/null 2>&1; then
      log_message "Docker daemon 已就绪。"
      return 0
    fi
    sleep 2
  done
  log_message "等待 Docker daemon 超时，请检查 systemctl 状态和服务日志。"
  return 1
}

# Deploy the API and TiDB containers from the shared Compose definition.
deploy_docker_compose() {
  local project_root="$1"
  local shared_directory="$project_root/Deployment/Docker/Shared"
  local environment_file="$shared_directory/.env"
  local api_port
  local attempt
  local lan_address
  local -a compose_files
  if [[ ! -f "$environment_file" ]]; then
    cp "$shared_directory/.env.example" "$environment_file"
    log_message "已创建默认部署配置：Deployment/Docker/Shared/.env"
  fi
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

  docker_command compose \
    --project-directory "$shared_directory" \
    --project-name repair-marketplace \
    "${compose_files[@]}" \
    --env-file "$environment_file" \
    build --builder default --build-arg "GO_VERSION=$(deployment_component GO_VERSION)" --build-arg "APP_BUILD_VERSION=demo-$(date -u +%Y%m%dT%H%M%SZ)"
  docker_command compose --project-directory "$shared_directory" --project-name repair-marketplace "${compose_files[@]}" --env-file "$environment_file" up --detach --no-build

  for attempt in {1..90}; do
    if curl --fail --silent --noproxy '*' --connect-timeout 2 --max-time 3 "http://127.0.0.1:$api_port/readyz" >/dev/null; then
      log_message "部署完成："
      log_message "  Web 管理后台：http://127.0.0.1:$api_port/admin/"
      log_message "  管理员登录：默认账号由程序自动创建；已有账号密码不会被部署覆盖。"
      log_message "  API 健康检查：http://127.0.0.1:$api_port/healthz"
      log_message "查看日志：docker compose --project-directory '$shared_directory' --project-name repair-marketplace --file '$shared_directory/compose.yaml' logs -f"
      return 0
    fi
    sleep 2
  done
  log_message "服务尚未通过健康检查，请查看 Compose 日志。"
  docker_command compose --project-directory "$shared_directory" --project-name repair-marketplace "${compose_files[@]}" logs --tail=100
  return 1
}
