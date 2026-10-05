#!/usr/bin/env bash
# Shared one-click Docker deployment flow for supported Linux distributions.

source "$SCRIPT_DIR/../../Shared/linux-functions.sh"

# Run the validated Docker route for the current Linux distribution.
deploy_linux_docker() {
  local project_root
  project_root="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  if [[ ! -f "$project_root/Server/go.mod" || ! -f "$project_root/Deployment/Docker/Shared/compose.yaml" ]]; then
    printf '无法从 Linux 入口位置定位 Docker 项目文件。\n入口目录：%s\n项目根目录候选：%s\n' "$SCRIPT_DIR" "$project_root" >&2
    return 1
  fi
  read_os_release
  detect_cpu_arch
  show_script_intro
  initialize_log
  validate_linux_platform
  source "$project_root/Deployment/Shared/components.sh"
  initialize_deployment_components "$project_root"
  select_local_docker_target linux
  ensure_downloader
  install_docker_engine
  validate_docker_server "$CPU_ARCH"
  ensure_buildx_plugin
  deploy_docker_compose "$project_root"
}
