#!/bin/zsh
# 脚本自述：
# - 脚本名称：Docker/macOS 一键部署
# - 核心用途：按 Apple 芯片类型准备 Docker Desktop，每次重新构建当前源码并部署 Go API 与 TiDB。
# - 影响范围：可能安装 Docker Desktop、创建部署配置并启动本项目容器。
# - 运行提示：双击后显示自述，回车确认；首次启动 Docker Desktop 时需在应用中接受许可。

setopt ERR_EXIT PIPE_FAIL NO_NOMATCH

# Run the shared Docker deployment flow for macOS.
run_deployment() {
  SCRIPT_PATH="${(%):-%x}"
  SCRIPT_PATH="${SCRIPT_PATH:A}"
  local script_directory="${SCRIPT_PATH:h}"
  local project_root="${script_directory}/../../.."
  local helper_path="${script_directory}/../Shared/macos-functions.zsh"
  project_root="${project_root:A}"
  if [[ ! -f "$helper_path" || ! -f "$project_root/Deployment/Docker/Shared/Dockerfile" ]]; then
    printf '无法从脚本位置定位 Docker 部署文件。\n入口：%s\n项目根目录候选：%s\n' "$SCRIPT_PATH" "$project_root" >&2
    return 1
  fi
  DEPLOYMENT_NAME="docker"
  PROJECT_ROOT="$project_root"
  source "$helper_path"
  detect_macos_arch
  show_macos_intro
  initialize_macos_log
  load_macos_components
  ensure_docker_desktop
  prepare_compose_environment
  deploy_compose_stack
}

# Keep the file's main entry limited to orchestration.
main() {
  run_deployment "$@"
}

main "$@"
