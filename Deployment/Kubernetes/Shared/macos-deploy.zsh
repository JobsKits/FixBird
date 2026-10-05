# Shared macOS Kubernetes bootstrap flow using Docker Desktop and Minikube.

# Log Kubernetes deployment messages to the terminal and the run log.
log_kubernetes() {
  printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

# Proxy host-side Minikube downloads while keeping cluster traffic local.
run_minikube_with_proxy() {
  if [[ -n "${DEPLOYMENT_HTTP_PROXY:-}" && -n "${DEPLOYMENT_HTTPS_PROXY:-}" ]]; then
    local bypass='localhost,127.0.0.1,::1,host.docker.internal,192.168.49.0/24,192.168.59.0/24,192.168.39.0/24,10.96.0.0/12'
    env -u DOCKER_CONTEXT HTTP_PROXY="$DEPLOYMENT_HTTP_PROXY" HTTPS_PROXY="$DEPLOYMENT_HTTPS_PROXY" \
      http_proxy="$DEPLOYMENT_HTTP_PROXY" https_proxy="$DEPLOYMENT_HTTPS_PROXY" \
      DOCKER_HOST="$DEPLOYMENT_DOCKER_HOST" \
      NO_PROXY="$bypass" no_proxy="$bypass" minikube --profile=minikube "$@"
  else
    env -u DOCKER_CONTEXT DOCKER_HOST="$DEPLOYMENT_DOCKER_HOST" minikube --profile=minikube "$@"
  fi
}

# Download the pinned Minikube binary matching this Mac's CPU architecture.
install_minikube_macos() {
  local binary_directory="$HOME/.local/bin"
  local binary_path="$binary_directory/minikube"
  mkdir -p "$binary_directory"
  if [[ -x "$binary_path" ]] && "$binary_path" version --short >/dev/null 2>&1; then
    PATH="$binary_directory:$PATH"
    export PATH
    return 0
  fi
  if command -v minikube >/dev/null 2>&1 && minikube version --short >/dev/null 2>&1; then
    log_kubernetes "复用已健康的 Minikube，不自动更换版本。"
    return 0
  fi
  log_kubernetes "按 $MAC_CPU_ARCH 架构下载固定版本 Minikube。"
  local download_directory="$(mktemp -d -t repair-minikube)"
  if ! download_deployment_component "MINIKUBE_DARWIN_${(U)MAC_CPU_ARCH}" "$download_directory/minikube"; then
    rm -f "$download_directory/minikube"
    rmdir "$download_directory"
    log_kubernetes "Minikube 下载失败，保留原有工具。"
    return 1
  fi
  chmod 0755 "$download_directory/minikube"
  if [[ "$("$download_directory/minikube" version --short)" != "$(deployment_component MINIKUBE_VERSION)" ]]; then
    rm -f "$download_directory/minikube"
    rmdir "$download_directory"
    log_kubernetes "Minikube 下载文件版本检查失败，保留原有工具。"
    return 1
  fi
  mv "$download_directory/minikube" "$binary_path"
  rmdir "$download_directory"
  PATH="$binary_directory:$PATH"
  export PATH
}
# 只接受 Docker 驱动的已有单节点 profile，便于独立测试此门禁。
validate_minikube_profile_metadata() {
  local profile_file="$1"
  [[ "$(plutil -extract Driver raw -o - "$profile_file")" == docker ]] || { log_kubernetes '已有 minikube profile 使用其它驱动，已停止。'; return 1; }
  [[ -n "$(plutil -extract Nodes.0.Name raw -o - "$profile_file" 2>/dev/null)" ]] || { log_kubernetes '已有 minikube profile 缺少节点记录，已停止。'; return 1; }
  if plutil -extract Nodes.1.Name raw -o - "$profile_file" >/dev/null 2>&1; then
    log_kubernetes '已有 minikube profile 是多节点，当前入口只支持单节点。'
    return 1
  fi
}
# 保留既有 default profile 的数据，复用前明确确认归属并拒绝多节点。
confirm_minikube_profile() {
  local profile_file="$HOME/.minikube/profiles/minikube/config.json" confirmation=''
  [[ -z "${MINIKUBE_HOME:-}" && -z "${KUBECONFIG:-}" ]] || { log_kubernetes '标准部署不接受 MINIKUBE_HOME / KUBECONFIG 覆盖，请取消后重试。'; return 1; }
  if [[ -f "$profile_file" ]]; then
    validate_minikube_profile_metadata "$profile_file" || return 1
    log_kubernetes '发现已有 minikube profile；将保留 PVC，更新其中 repair-marketplace namespace。请先核对该集群归属。'
    [[ -t 0 ]] || return 1
    read -r 'confirmation?确认这是本项目可使用的本机集群：回车取消；输入任意字符后回车复用：' || return 1
    [[ -n "$confirmation" ]] || return 1
  else
    log_kubernetes '将创建本机单节点 minikube profile；不自动迁移其它集群或 Docker 数据。'
  fi
}
# 固定 kubectl 的 context，避免继承用户当前其它集群凭据。
minikube_kubectl() {
  run_minikube_with_proxy kubectl -- --context=minikube "$@"
}

# Build the app image, load it into Minikube, and apply the Kubernetes manifests.
deploy_minikube_workload() {
  local image_tag="repair-marketplace-api:local"
  local manifest="$PROJECT_ROOT/Deployment/Kubernetes/Shared/workloads.yaml"
  local api_port="${KUBERNETES_API_PORT:-8081}"
  if [[ "$api_port" != <1-65535> ]]; then
    log_kubernetes "KUBERNETES_API_PORT 必须是 1–65535 的端口。"
    return 1
  fi

  log_kubernetes "检查并启动 Minikube Docker 驱动单节点集群。"
  run_minikube_with_proxy start --keep-context --driver=docker --cpus=2 --memory=4096 --disk-size=20g
  log_kubernetes "构建并导入 macOS/$MAC_CPU_ARCH 对应的 Linux 应用镜像。"
  run_docker_with_proxy build \
    --builder default \
    --platform "linux/$MAC_CPU_ARCH" \
    --build-arg "GO_VERSION=$(deployment_component GO_VERSION)" \
    --build-arg "APP_BUILD_VERSION=demo-$(date -u +%Y%m%dT%H%M%SZ)" \
    --file "$PROJECT_ROOT/Deployment/Docker/Shared/Dockerfile" \
    --tag "$image_tag" \
    "$PROJECT_ROOT"
  run_minikube_with_proxy image load "$image_tag"
  # Import through the host engine so the node need not authenticate directly.
  run_docker_with_proxy pull pingcap/tidb:v8.5.8
  run_minikube_with_proxy image load pingcap/tidb:v8.5.8
  minikube_kubectl apply -f "$manifest"
  minikube_kubectl -n repair-marketplace rollout status statefulset/tidb --timeout=360s
  minikube_kubectl -n repair-marketplace rollout restart deployment/repair-api
  minikube_kubectl -n repair-marketplace rollout status deployment/repair-api --timeout=360s
  log_kubernetes "Kubernetes 部署已就绪；保持此 Terminal 窗口打开以维持 API 端口转发。"
  log_kubernetes "  Web 管理后台：http://127.0.0.1:$api_port/admin/"
  log_kubernetes "  API 健康检查：http://127.0.0.1:$api_port/healthz"
  open "http://127.0.0.1:$api_port/admin/"
  minikube_kubectl -n repair-marketplace port-forward --address=127.0.0.1 service/repair-api "$api_port:8080"
}
