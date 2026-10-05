#!/bin/zsh
# 脚本自述：
# - 脚本名称：Kubernetes/macOS 一键部署
# - 核心用途：准备 Docker Desktop 与 Minikube 单节点集群，部署 Go API 与 TiDB。
# - 影响范围：可能安装 Docker Desktop / Minikube 并在本机创建 Kubernetes 工作负载。
# - 运行提示：双击后自动执行；首次启动 Docker Desktop 时需在应用中接受许可。

setopt ERR_EXIT PIPE_FAIL NO_NOMATCH

# Run the shared Kubernetes deployment flow for macOS.
run_deployment() {
  SCRIPT_PATH="${(%):-%x}"
  SCRIPT_PATH="${SCRIPT_PATH:A}"
  local script_directory="${SCRIPT_PATH:h}"
  local project_root="${script_directory}/../../.."
  local docker_helper_path="${script_directory}/../../Docker/Shared/macos-functions.zsh"
  local kubernetes_helper_path="${script_directory}/../Shared/macos-deploy.zsh"
  project_root="${project_root:A}"
  if [[ ! -f "$docker_helper_path" || ! -f "$kubernetes_helper_path" || ! -f "$project_root/Deployment/Docker/Shared/Dockerfile" || ! -f "$project_root/Deployment/Kubernetes/Shared/workloads.yaml" ]]; then
    printf '无法从脚本位置定位 Kubernetes 部署文件。\n入口：%s\n项目根目录候选：%s\n' "$SCRIPT_PATH" "$project_root" >&2
    return 1
  fi
  DEPLOYMENT_NAME="kubernetes"
  PROJECT_ROOT="$project_root"
  source "$docker_helper_path"
  source "$kubernetes_helper_path"
  detect_macos_arch
  show_macos_intro
  initialize_macos_log
  load_macos_components
  confirm_minikube_profile
  ensure_docker_desktop
  install_minikube_macos
  deploy_minikube_workload
}

# Keep the file's main entry limited to orchestration.
main() {
  run_deployment "$@"
}

main "$@"
