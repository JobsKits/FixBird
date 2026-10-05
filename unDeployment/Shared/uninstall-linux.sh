#!/usr/bin/env bash
# 脚本自述：仅供各 Linux 反安装入口加载；卸载本机 K3s、Docker Engine / Compose 和全部容器数据。
# 不连接远程 Docker / Kubernetes；失败立即停止，保留日志以便再次执行。

# 输出步骤信息；入口已把标准输出和错误同步到日志。
cleanup_log() {
  printf '\033[1;34mℹ %s\033[0m\n' "$*"
}
# 只在系统级卸载步骤获取管理员权限。
cleanup_root() {
  if [[ "$(id -u)" == 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}
# 准备日志、项目路径和发行版校验，不安装任何依赖。
initialize_cleanup() {
  set -Eeuo pipefail
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/repair-uninstall-linux.XXXXXX")"
  exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'printf "✖ 反安装失败（行 %s），未完成清场。日志：%s\n" "$LINENO" "$LOG_FILE" >&2' ERR
  [[ "$(uname -s)" == Linux ]] || { cleanup_log '此入口仅支持 Linux。'; exit 1; }
  [[ -f "$PROJECT_ROOT/Deployment/Docker/Shared/compose.yaml" ]] || exit 1
  [[ -r /etc/os-release ]] || exit 1
  . /etc/os-release
  [[ "|$EXPECTED_OS_IDS|" == *"|$ID|"* ]] || { cleanup_log "发行版不匹配：$ID"; exit 1; }
  [[ -n "$HOME" && "$HOME" == /* && "$HOME" != / ]] || exit 1
  command -v findmnt >/dev/null || { cleanup_log '缺少 findmnt，无法验证残留挂载；请先修复系统工具。'; exit 1; }
  command -v pgrep >/dev/null || { cleanup_log '缺少 pgrep，无法验证容器写入者已退出；停止清场。'; exit 1; }
  source "$PROJECT_ROOT/Deployment/Shared/components.sh"
  initialize_deployment_components "$PROJECT_ROOT"
  cleanup_log "日志：$LOG_FILE"
}
# 拒绝 live-restore：停 daemon 不足以证明容器已经停止写入。
assert_no_live_restore() {
  local daemon_settings='' service_command='' live_restore=''
  if cleanup_root test -f /etc/docker/daemon.json; then
    daemon_settings="$(cleanup_root cat /etc/docker/daemon.json | tr -d '\r\n')"
    if printf '%s' "$daemon_settings" | grep -Eq '"live-restore"[[:space:]]*:[[:space:]]*true'; then
      cleanup_log '发现 Docker live-restore=true，不能保证停止写入；请先关闭该设置并按维护计划重启 daemon 后重试。'
      return 1
    fi
  fi
  if command -v systemctl >/dev/null 2>&1; then
    service_command="$(systemctl show docker.service -p ExecStart --value 2>/dev/null || true)"
    [[ "$service_command" != *--live-restore* ]] || { cleanup_log 'Docker 服务含 live-restore 参数，停止清场。'; return 1; }
  fi
  if command -v docker >/dev/null 2>&1; then
    live_restore="$(cleanup_root env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host unix:///var/run/docker.sock info --format '{{.LiveRestoreEnabled}}' 2>/dev/null || true)"
    [[ "$live_restore" != true ]] || { cleanup_log '运行中的 Docker 启用了 live-restore，停止清场。'; return 1; }
  fi
}
# 归档前验证 runtime/shim/数据库进程已退出，不杀猜测出来的进程。
assert_no_container_writers() {
  local process_status=0
  if pgrep -f '[c]ontainerd-shim|[d]ocker-containerd-shim|[d]ockerd|[k]3s server|[t]idb-server' >/dev/null; then
    cleanup_log '仍有容器或数据库写入者，未执行数据归档；请确认全部相关服务正常停止后重试。'
    return 1
  else
    process_status=$?
  fi
  [[ "$process_status" == 1 ]] || { cleanup_log '无法确认容器进程状态，未执行归档。'; return 1; }
}
# 在停服或卸载前检查手工插件归属，避免到清理末尾才发现未知安装。
verify_owned_linux_plugins() {
  local receipt=/var/lib/repair-marketplace-deployment/owned-plugins.tsv plugin_path expected_sha
  for plugin_path in /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-buildx; do
    if cleanup_root test -e "$plugin_path"; then
      if cleanup_root test -L "$plugin_path"; then
        cleanup_log "手工插件是符号链接，停止清场：$plugin_path"
        return 1
      fi
      expected_sha="$(cleanup_root awk -F '\t' -v path="$plugin_path" '$1 == path { hash=$2 } END { print hash }' "$receipt" 2>/dev/null)" || return 1
      [[ "$expected_sha" =~ ^[a-f0-9]{64}$ && "$(deployment_sha256 "$plugin_path")" == "$expected_sha" ]] || { cleanup_log "手工插件没有有效安装收据或已被修改，停止清场：$plugin_path"; return 1; }
    fi
  done
}
# 仅清理本项目记录且摘要一致的手工插件，不删除归属不明文件。
remove_owned_linux_plugins() {
  local receipt=/var/lib/repair-marketplace-deployment/owned-plugins.tsv plugin_path expected_sha
  verify_owned_linux_plugins || return 1
  if cleanup_root test -f "$receipt"; then
    while IFS=$'\t' read -r plugin_path expected_sha; do
      case "$plugin_path" in
        /usr/local/lib/docker/cli-plugins/docker-compose|/usr/local/lib/docker/cli-plugins/docker-buildx) ;;
        *) cleanup_log "插件归属记录包含未知路径，停止：$plugin_path"; return 1 ;;
      esac
      if cleanup_root test -e "$plugin_path"; then
        [[ "$(deployment_sha256 "$plugin_path")" == "$expected_sha" ]] || { cleanup_log "插件已被其它安装修改，未删除：$plugin_path"; return 1; }
        cleanup_root rm -f -- "$plugin_path"
      fi
    done < <(cleanup_root awk -F '\t' '{ hashes[$1]=$2 } END { for (path in hashes) print path "\t" hashes[path] }' "$receipt")
    cleanup_root rm -f -- "$receipt"
  fi
  for plugin_path in /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-buildx; do
    if cleanup_root test -e "$plugin_path"; then
      cleanup_log "保留没有本项目安装记录的手工插件：${plugin_path}；请核对所属安装器，不能宣称完整清场。"
      return 1
    fi
  done
}
# 检查包管理器、标准数据路径与官方卸载器，避免对未知安装方式谎报成功。
inspect_cleanup_targets() {
  assert_no_live_restore
  verify_owned_linux_plugins
  PACKAGES=()
  local package_name package_state
  if command -v dpkg-query >/dev/null; then
    PACKAGE_MANAGER=apt
  elif command -v rpm >/dev/null; then
    if command -v dnf >/dev/null; then
      PACKAGE_MANAGER=dnf
    elif command -v yum >/dev/null; then
      PACKAGE_MANAGER=yum
    elif command -v zypper >/dev/null; then
      PACKAGE_MANAGER=zypper
    else
      cleanup_log '没有可用的 RPM 包管理器。'; exit 1
    fi
  else
    cleanup_log '未知包管理器，停止清场。'; exit 1
  fi
  for package_name in docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin docker-compose docker-compose-v2 docker.io docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine moby-engine moby-cli moby-buildx moby-compose containerd.io containerd runc; do
    if [[ "$PACKAGE_MANAGER" == apt ]]; then
      package_state="$(dpkg-query -W -f='${db:Status-Abbrev}' "$package_name" 2>/dev/null || true)"
      [[ "$package_state" == ii* || "$package_state" == rc* ]] && PACKAGES+=("$package_name")
    elif rpm -q "$package_name" >/dev/null 2>&1; then
      PACKAGES+=("$package_name")
    fi
  done
  if command -v k3s >/dev/null && [[ ! -x /usr/local/bin/k3s-uninstall.sh ]]; then
    cleanup_log '发现 K3s，但没有标准官方卸载器；请先恢复卸载器。'; exit 1
  fi
  if [[ -f /etc/docker/daemon.json ]] && cleanup_root grep -Eq '"(data-root|exec-root)"' /etc/docker/daemon.json; then
    cleanup_log '发现自定义 Docker 数据路径，请按实际路径清场；本入口不猜测或递归删除未知目录。'; exit 1
  fi
  if [[ -d "$HOME/.local/share/docker" || -n "${DOCKER_HOST:-}" || -n "${DOCKER_CONTEXT:-}" ]]; then
    cleanup_log '发现 rootless 数据或 Docker 环境覆盖；请先处理该自定义环境，再运行标准主机清场。'; exit 1
  fi
  cleanup_log '待卸载软件包：'
  if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    cleanup_log '  - 无'
  else
    for package_name in "${PACKAGES[@]}"; do
      cleanup_log "  - $package_name"
    done
  fi
  cleanup_log '待删除：本机 K3s 全集群、Docker / containerd 全部数据、配置、仓库源与项目 .env。'
  cleanup_log '两个部署路线共用运行环境；从任一入口清场都会让另一条路线停止工作。'
}
# 用精确 YES 确认整台主机的容器环境清场。
confirm_cleanup_targets() {
  local answer=''
  printf '数据处理：1、先备份再卸载（默认）；2、永久删除全部容器和集群数据。\n'
  IFS= read -r -p '请选择 [1/2]：' answer || exit 1
  case "$answer" in
    ''|1) DATA_MODE=backup ;;
    2) DATA_MODE=delete ;;
    *) cleanup_log '无效选项，已取消。'; exit 1 ;;
  esac
  cleanup_log "数据策略：${DATA_MODE}；涉及其它项目的容器、镜像、卷和 K3s 数据。"
  cleanup_log '备份模式会停服后打包到当前用户 RepairMarketplaceBackups 目录；失败立即停止卸载。'
  IFS= read -r -p '输入 YES 执行整套反安装，其它输入取消：' answer || exit 1
  [[ "$answer" == YES ]] || { cleanup_log '已取消，未执行卸载。'; exit 0; }
}
# 停止写入后制作完整本机数据归档；备份失败不会进入卸载步骤。
backup_linux_data() {
  [[ "$DATA_MODE" == backup ]] || return 0
  assert_no_live_restore
  local unit target
  local backup_items=()
  BACKUP_DIR="$HOME/RepairMarketplaceBackups/$(date +%Y%m%d-%H%M%S)-$$"
  (umask 077; mkdir -p "$BACKUP_DIR")
  if [[ -x /usr/local/bin/k3s-killall.sh ]]; then
    cleanup_root /usr/local/bin/k3s-killall.sh
  fi
  if command -v systemctl >/dev/null; then
    for unit in k3s.service docker.socket docker.service containerd.service; do
      if [[ "$(systemctl show "$unit" -p LoadState --value)" != not-found ]]; then
        cleanup_root systemctl stop "$unit"
      fi
    done
  elif [[ -x /etc/init.d/docker ]]; then
    cleanup_root service docker stop
  fi
  assert_no_container_writers
  for target in /var/lib/docker /var/lib/containerd /var/lib/rancher/k3s /etc/rancher /etc/docker /etc/containerd "$HOME/.docker" "$HOME/.kube" "$PROJECT_ROOT/Deployment/Docker/Shared/.env"; do
    if cleanup_root test -e "$target"; then
      backup_items+=("${target#/}")
    fi
  done
  if [[ ${#backup_items[@]} -gt 0 ]]; then
    cleanup_root tar --acls --xattrs --numeric-owner -cpf "$BACKUP_DIR/data.tar" -C / "${backup_items[@]}"
    cleanup_root tar -tf "$BACKUP_DIR/data.tar" >/dev/null
    cleanup_root chmod 600 "$BACKUP_DIR/data.tar"
  fi
  cleanup_log "✔ 数据归档已验证：${BACKUP_DIR}；恢复时需安装兼容版本并停服还原原路径。"
}
# 使用 K3s 安装时生成的卸载器清理服务、网络和持久化数据。
remove_k3s_runtime() {
  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    cleanup_log '卸载 K3s 及整个本地集群。'
    cleanup_root /usr/local/bin/k3s-uninstall.sh
  elif [[ -d /var/lib/rancher/k3s || -d /etc/rancher/k3s ]]; then
    cleanup_log 'K3s 残留存在但卸载器缺失，无法保证网络清理；停止。'; exit 1
  fi
}
# 停止存在的系统服务，再通过对应包管理器卸载容器工具。
remove_docker_packages() {
  local unit
  if command -v systemctl >/dev/null; then
    for unit in docker.socket docker.service containerd.service; do
      if [[ "$(systemctl show "$unit" -p LoadState --value)" != not-found ]]; then
        cleanup_root systemctl stop "$unit"
        cleanup_root systemctl disable "$unit"
      fi
    done
  elif command -v service >/dev/null && [[ -x /etc/init.d/docker ]]; then
    cleanup_root service docker stop
  fi
  if [[ ${#PACKAGES[@]} -gt 0 ]]; then
    case "$PACKAGE_MANAGER" in
      apt) cleanup_root apt-get purge -y "${PACKAGES[@]}" ;;
      dnf) cleanup_root dnf remove -y --setopt=clean_requirements_on_remove=False "${PACKAGES[@]}" ;;
      yum) cleanup_root yum remove -y --setopt=clean_requirements_on_remove=0 "${PACKAGES[@]}" ;;
      zypper) cleanup_root zypper --non-interactive remove "${PACKAGES[@]}" ;;
    esac
  fi
}
# 删除固定清单内的残留；任何仍挂载的数据目录都会阻止删除。
remove_linux_residue() {
  local target mounted_targets mount_target
  remove_owned_linux_plugins
  mounted_targets="$(findmnt -rn -o TARGET)"
  for target in /var/lib/docker /var/lib/containerd /etc/docker /etc/containerd /run/docker /run/containerd /var/run/docker.sock /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc /etc/apt/keyrings/docker.gpg /usr/share/keyrings/docker-archive-keyring.gpg /etc/yum.repos.d/docker-ce.repo "$HOME/.docker" "$PROJECT_ROOT/Deployment/Docker/Shared/.env"; do
    while IFS= read -r mount_target; do
      if [[ "$mount_target" == "$target" || "$mount_target" == "$target/"* ]]; then
        cleanup_log "目录仍被挂载，停止删除：$mount_target"; exit 1
      fi
    done <<< "$mounted_targets"
    cleanup_log "清理：$target"
    cleanup_root rm -rf -- "$target"
  done
  if command -v systemctl >/dev/null; then
    cleanup_root systemctl daemon-reload
  fi
}
# 验证主要运行时已消失，保留失败日志供人工定位非标准安装。
verify_linux_cleanup() {
  hash -r
  local command_name
  for command_name in docker dockerd containerd k3s; do
    if command -v "$command_name" >/dev/null; then
      cleanup_log "仍有可执行文件：$(command -v "$command_name")；可能属于手工安装，清场未完成。"; exit 1
    fi
  done
  cleanup_log "✔ 标准容器环境清场完成。审计日志保留于：$LOG_FILE"
}
