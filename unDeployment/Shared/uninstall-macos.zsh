# 脚本自述：仅供 macOS 反安装入口加载；清除全部 Minikube 集群、Docker Desktop 和容器数据。
# 使用官方卸载器，不按当前 kubectl context 删除远程集群。

# 输出步骤信息；终端与日志由初始化函数统一同步。
cleanup_log() {
  printf '\033[1;34mℹ %s\033[0m\n' "$*"
}
# 确认平台、定位项目并在系统临时目录保留反安装日志。
initialize_cleanup() {
  setopt ERR_EXIT PIPE_FAIL NO_NOMATCH
  SCRIPT_DIR="${SCRIPT_PATH:h}"
  PROJECT_ROOT="${SCRIPT_DIR}/../../.."
  PROJECT_ROOT="${PROJECT_ROOT:A}"
  [[ "$(uname -s)" == Darwin ]] || { print -u2 '此入口仅支持 macOS。'; exit 1; }
  [[ -n "$HOME" && "$HOME" == /* && "$HOME" != / ]] || exit 1
  [[ -f "$PROJECT_ROOT/Deployment/Docker/Shared/compose.yaml" ]] || exit 1
  LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/repair-uninstall-macos.XXXXXX")"
  exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'print -u2 "✖ 清场未完成，请检查权限、Docker 运行状态及日志：$LOG_FILE"' ZERR
  PATH="$HOME/.local/bin:/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
  export PATH
  [[ -z "${MINIKUBE_HOME:-}" && -z "${DOCKER_HOST:-}" && -z "${DOCKER_CONTEXT:-}" && -z "${KUBECONFIG:-}" ]] || { cleanup_log '请先取消自定义运行环境变量，再清理标准本机环境。'; exit 1; }
  source "$PROJECT_ROOT/Deployment/Shared/components.sh"
  initialize_deployment_components "$PROJECT_ROOT"
  select_local_docker_target macos
  cleanup_log "日志：$LOG_FILE"
}
# 全部本地 profiles 的删除也必须固定到已验证的本机 daemon。
cleanup_docker() {
  [[ -n "${DEPLOYMENT_DOCKER_HOST:-}" ]] || { cleanup_log '尚未验证本机 Docker 目标，停止清场。'; return 1; }
  env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$DEPLOYMENT_DOCKER_HOST" "$@"
}
# 展示跨项目影响并要求精确确认，禁止回车直接清场。
confirm_cleanup_targets() {
  local answer=''
  cleanup_log '将删除当前用户所有 Minikube profiles、Minikube 工具、Docker Desktop 和其中全部项目数据。'
  cleanup_log '同时清理 Docker 配置、凭据配置文件、应用残留和本项目部署 .env。'
  print '数据处理：1、先备份再卸载（默认）；2、永久删除全部容器和集群数据。'
  read -r 'answer?请选择 [1/2]：' || exit 1
  case "$answer" in
    ''|1) DATA_MODE=backup ;;
    2) DATA_MODE=delete ;;
    *) cleanup_log '无效选项，已取消。'; exit 1 ;;
  esac
  cleanup_log "数据策略：${DATA_MODE}；备份保存在当前用户 RepairMarketplaceBackups 目录。"
  read -r 'answer?输入 YES 执行整套反安装，其它输入取消：' || exit 1
  [[ "$answer" == YES ]] || { cleanup_log '已取消，未执行卸载。'; exit 0; }
}
# 等待 Docker 完全退出后保存虚拟磁盘和配置，避免复制仍在写入的磁盘。
backup_macos_data() {
  [[ "$DATA_MODE" == backup ]] || return 0
  local attempt target settings_file custom_data profile_file driver_name
  local -a backup_items=()
  for settings_file in "$HOME/Library/Group Containers/group.com.docker/settings-store.json" "$HOME/Library/Group Containers/group.com.docker/settings.json"; do
    [[ -f "$settings_file" ]] || continue
    custom_data="$(/usr/bin/plutil -extract dataFolder raw -o - "$settings_file" 2>/dev/null || true)"
    if [[ -n "$custom_data" && "$custom_data" != "$HOME/Library/Containers/com.docker.docker/"* ]]; then
      cleanup_log "Docker 虚拟磁盘使用自定义路径，未纳入标准备份：${custom_data}；停止卸载。"; exit 1
    fi
  done
  for profile_file in "$HOME"/.minikube/profiles/*/config.json(N); do
    driver_name="$(/usr/bin/plutil -extract Driver raw -o - "$profile_file")"
    [[ "$driver_name" == docker ]] || { cleanup_log "非 Docker 驱动的 Minikube profile 需要专用备份：$profile_file"; exit 1; }
  done
  BACKUP_DIR="$HOME/RepairMarketplaceBackups/$(date +%Y%m%d-%H%M%S)-$$"
  (umask 077; mkdir -p "$BACKUP_DIR")
  if pgrep -x Docker >/dev/null || pgrep -f '/Docker.app/Contents/MacOS/com.docker.backend' >/dev/null; then
    osascript -e 'tell application "Docker" to quit'
    for attempt in {1..60}; do
      pgrep -f '/Docker.app/Contents/MacOS/com.docker.backend' >/dev/null || break
      sleep 2
    done
    if pgrep -f '/Docker.app/Contents/MacOS/com.docker.backend' >/dev/null; then
      cleanup_log 'Docker 后台未退出，无法制作一致备份；已停止。'; exit 1
    fi
  fi
  for target in "$HOME/Library/Containers/com.docker.docker" "$HOME/Library/Group Containers/group.com.docker" "$HOME/Library/Application Support/Docker Desktop" "$HOME/.docker" "$HOME/.minikube" "$HOME/.kube" "$PROJECT_ROOT/Deployment/Docker/Shared/.env"; do
    [[ ! -e "$target" ]] || backup_items+=("${target#/}")
  done
  if [[ ${#backup_items[@]} -gt 0 ]]; then
    tar -cpf "$BACKUP_DIR/data.tar" -C / "${backup_items[@]}"
    tar -tf "$BACKUP_DIR/data.tar" >/dev/null
    chmod 600 "$BACKUP_DIR/data.tar"
  fi
  cleanup_log "✔ 数据归档已验证：${BACKUP_DIR}；恢复时需安装兼容版本并停服还原。"
}
# 官方集群删除需要 Docker 可用；只启动已安装应用，不重新安装软件。
remove_minikube_runtime() {
  local attempt
  if [[ -d "$HOME/.minikube/profiles" ]]; then
    command -v minikube >/dev/null || { cleanup_log 'Minikube 数据存在但工具缺失，无法清理集群。'; exit 1; }
    if ! cleanup_docker info >/dev/null 2>&1; then
      [[ -d /Applications/Docker.app ]] || { cleanup_log 'Docker Desktop 缺失，请修复环境后重试集群删除。'; exit 1; }
      open -a Docker
      for attempt in {1..60}; do
        cleanup_docker info >/dev/null 2>&1 && break
        sleep 2
      done
      cleanup_docker info >/dev/null
    fi
    env -u DOCKER_CONTEXT DOCKER_HOST="$DEPLOYMENT_DOCKER_HOST" minikube delete --all --purge
  fi
  if command -v brew >/dev/null && brew list --formula minikube >/dev/null 2>&1; then
    brew uninstall minikube
  fi
  rm -f -- "$HOME/.local/bin/minikube"
  if command -v minikube >/dev/null; then
    cleanup_log "发现非部署脚本安装的 Minikube：$(command -v minikube)，请用所属安装器卸载后重试。"; exit 1
  fi
  rm -rf -- "$HOME/.minikube"
}
# 调用 Docker Desktop 官方卸载器并处理 Homebrew 登记。
remove_docker_desktop() {
  if [[ -d /Applications/Docker.app ]]; then
    [[ -x /Applications/Docker.app/Contents/MacOS/uninstall ]] || { cleanup_log 'Docker 官方卸载器缺失；请恢复安装器后重试。'; exit 1; }
    /Applications/Docker.app/Contents/MacOS/uninstall
  fi
  if command -v brew >/dev/null; then
    local cask_name
    for cask_name in docker docker-desktop; do
      if brew list --cask "$cask_name" >/dev/null 2>&1; then
        brew uninstall --cask --force "$cask_name"
      fi
    done
  fi
  sudo rm -rf -- /Applications/Docker.app
}
# 清除官方列出的用户数据与固定项目配置，保留源码及其它 Kubernetes 配置。
remove_macos_residue() {
  local target
  for target in "$HOME/Library/Containers/com.docker.docker" "$HOME/Library/Group Containers/group.com.docker" "$HOME/Library/Application Support/Docker Desktop" "$HOME/Library/Logs/Docker Desktop" "$HOME/Library/Preferences/com.docker.docker.plist" "$HOME/.docker" "$PROJECT_ROOT/Deployment/Docker/Shared/.env"; do
    cleanup_log "清理：$target"
    rm -rf -- "$target"
  done
}
# 核对默认安装与数据路径；权限拦截会以失败退出而非假报成功。
verify_macos_cleanup() {
  rehash
  [[ ! -e /Applications/Docker.app && ! -e "$HOME/.minikube" && ! -e "$HOME/.docker" ]] || exit 1
  if command -v docker >/dev/null || command -v minikube >/dev/null; then
    cleanup_log 'PATH 中仍存在其它来源的 Docker / Minikube，请用对应包管理器卸载；清场未完成。'; exit 1
  fi
  cleanup_log "✔ 标准容器环境清场完成。审计日志保留于：$LOG_FILE"
}
