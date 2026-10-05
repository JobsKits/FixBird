#!/usr/bin/env bash
# Shared one-click Kubernetes deployment flow for supported Linux distributions.

source "$SCRIPT_DIR/../../../Docker/Shared/linux-functions.sh"

# Write Kubernetes deployment messages to the terminal and run log.
log_kubernetes() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

# Explain the Kubernetes deployment scope before making host changes.
show_kubernetes_intro() {
  printf '\n啄木鸟维修平台 · Kubernetes 一键部署\n'
  printf '脚本入口：%s\n' "$SCRIPT_PATH"
  printf '系统：%s %s；架构：%s\n' "$PRETTY_NAME" "$VERSION_ID" "$CPU_ARCH"
  printf '范围：按需安装 Docker 构建工具与 K3s 单节点集群，再部署 Go API 和 TiDB。\n'
  printf '影响：安装系统软件包、启用容器 / Kubernetes 服务并创建本地集群。\n'
  printf '日志：$HOME/.local/state/repair-platform/repair-platform-kubernetes.log\n\n'
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

# Initialize the shared system log after the intro has been printed.
initialize_kubernetes_log() {
  LOG_DIRECTORY="$HOME/.local/state/repair-platform"
  mkdir -p "$LOG_DIRECTORY"
  LOG_FILE="$LOG_DIRECTORY/repair-platform-kubernetes.log"
  touch "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

# 固定本机 K3s 配置，不继承当前终端的远端 KUBECONFIG。
k3s_command() {
  run_as_root env -u KUBECONFIG k3s kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml "$@"
}
# 标准单节点安装不继承可把服务器变成远端 agent 的安装器环境参数。
validate_k3s_install_environment() {
  local overrides
  overrides="$(env | awk -F= '$1 ~ /^(K3S_|INSTALL_K3S_)/ { print $1 }')"
  [[ -z "$overrides" ]] || { log_kubernetes "发现 K3s 安装环境覆盖，标准单节点入口已停止。请取消这些变量后重试（仅显示名称）：\n$overrides"; return 1; }
}
# 验证 kubeconfig 指向回环服务，节点只有一台且机器 ID 为本机。
validate_local_k3s_cluster() {
  local server nodes node_name machine_id expected_machine_id
  server="$(k3s_command config view --minify -o 'jsonpath={.clusters[0].cluster.server}')" || return 1
  case "$server" in
    https://127.0.0.1:*|https://localhost:*|https://\[::1\]:*) ;;
    *) log_kubernetes "K3s 配置不是本机回环目标，拒绝操作：$server"; return 1 ;;
  esac
  nodes="$(k3s_command get nodes -o 'jsonpath={range .items[*]}{.metadata.name}{"|"}{.status.nodeInfo.machineID}{"\n"}{end}')" || return 1
  if [[ -z "$nodes" || "$(printf '%s\n' "$nodes" | wc -l | tr -d ' ')" != 1 ]]; then
    log_kubernetes '此入口只支持本机单节点 K3s，已拒绝空节点或已有多节点集群。'
    return 1
  fi
  node_name="${nodes%%|*}"
  machine_id="${nodes#*|}"
  expected_machine_id="$(cat /etc/machine-id)"
  [[ -n "$expected_machine_id" && "$machine_id" == "$expected_machine_id" ]] || { log_kubernetes "节点不是本机 machine-id，拒绝镜像导入与部署：$node_name"; return 1; }
  log_kubernetes "已确认本机单节点集群：${node_name}；将更新 repair-marketplace namespace。"
}
# Install a single-node K3s runtime and deploy the shared workload.
deploy_linux_kubernetes() {
  local project_root
  local temporary_directory
  local k3s_installer
  local image_archive
  local image_tag="repair-marketplace-api:local"
  local api_port="${KUBERNETES_API_PORT:-8081}"
  if [[ ! "$api_port" =~ ^[0-9]+$ ]] || (( 10#$api_port < 1 || 10#$api_port > 65535 )); then
    printf 'KUBERNETES_API_PORT 必须是 1–65535 的端口。\n' >&2
    return 1
  fi

  project_root="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  if [[ ! -f "$project_root/Server/go.mod" || ! -f "$project_root/Deployment/Docker/Shared/Dockerfile" || ! -f "$project_root/Deployment/Kubernetes/Shared/workloads.yaml" ]]; then
    printf '无法从 Linux 入口位置定位 Kubernetes 项目文件。\n入口目录：%s\n项目根目录候选：%s\n' "$SCRIPT_DIR" "$project_root" >&2
    return 1
  fi
  read_os_release
  detect_cpu_arch
  show_kubernetes_intro
  initialize_kubernetes_log
  validate_linux_platform
  source "$project_root/Deployment/Shared/components.sh"
  initialize_deployment_components "$project_root"
  select_local_docker_target linux
  if command -v k3s >/dev/null 2>&1; then
    validate_local_k3s_cluster
  else
    validate_k3s_install_environment
  fi
  ensure_downloader
  install_docker_engine
  validate_docker_server "$CPU_ARCH"
  ensure_buildx_plugin

  if ! command -v k3s >/dev/null 2>&1; then
    temporary_directory="$(mktemp -d)"
    k3s_installer="$temporary_directory/install-k3s.sh"
    log_kubernetes "下载已固定版本和 SHA256 的 K3s 官方安装脚本。"
    download_deployment_component K3S_INSTALL "$k3s_installer"
    run_as_root env INSTALL_K3S_VERSION="$(deployment_component K3S_VERSION)" sh "$k3s_installer"
    rm -rf "$temporary_directory"
  else
    run_as_root systemctl enable --now k3s
  fi

  log_kubernetes "等待 K3s 单节点就绪。"
  k3s_command wait --for=condition=Ready node --all --timeout=240s
  validate_local_k3s_cluster

  log_kubernetes "构建 Linux/$CPU_ARCH 应用镜像。"
  docker_command build \
    --builder default \
    --platform "linux/$CPU_ARCH" \
    --build-arg "GO_VERSION=$(deployment_component GO_VERSION)" \
    --build-arg "APP_BUILD_VERSION=demo-$(date -u +%Y%m%dT%H%M%SZ)" \
    --file "$project_root/Deployment/Docker/Shared/Dockerfile" \
    --tag "$image_tag" \
    "$project_root"
  temporary_directory="$(mktemp -d)"
  image_archive="$temporary_directory/repair-marketplace-api.tar"
  docker_command save "$image_tag" --output "$image_archive"
  run_as_root k3s ctr images import "$image_archive"

  log_kubernetes "应用 Kubernetes 工作负载并等待 TiDB / Go API 就绪。"
  k3s_command apply -f "$project_root/Deployment/Kubernetes/Shared/workloads.yaml"
  k3s_command -n repair-marketplace rollout status statefulset/tidb --timeout=360s
  k3s_command -n repair-marketplace rollout restart deployment/repair-api
  k3s_command -n repair-marketplace rollout status deployment/repair-api --timeout=360s
  rm -rf "$temporary_directory"

  log_kubernetes "Kubernetes 部署已就绪。关闭此终端会结束本机端口转发。"
  log_kubernetes "  Web 管理后台：http://127.0.0.1:$api_port/admin/"
  log_kubernetes "  API 健康检查：http://127.0.0.1:$api_port/healthz"
  k3s_command -n repair-marketplace port-forward --address 127.0.0.1 service/repair-api "$api_port:8080"
}
