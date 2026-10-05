#!/usr/bin/env bash
# 脚本自述：
# - 脚本名称：Kubernetes/Linux/Debian 一键部署
# - 核心用途：在匹配的 Debian 上自动安装 Docker 镜像构建工具与 K3s 单节点集群，并部署 Go API、Web 管理后台和 TiDB。
# - 影响范围：可能安装系统软件包、启用 Docker / K3s 服务，并在主机上创建 Kubernetes 工作负载。
# - 运行提示：检测发行版版本与 CPU 架构；管理员权限通过 sudo 获取。

set -Eeuo pipefail

# Load the shared deployment flow after the one-click entry begins.
run_deployment() {
  SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
  SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
  if [[ ! -f "$SCRIPT_DIR/../../Shared/deploy-linux.sh" ]]; then
    printf '无法从入口脚本位置定位 Linux 部署共享脚本。\n入口：%s\n预期文件：%s\n' "$SCRIPT_PATH" "$SCRIPT_DIR/../../Shared/deploy-linux.sh" >&2
    return 1
  fi
  EXPECTED_OS_IDS='debian'
  EXPECTED_NAME_FRAGMENT='Debian'
  SUPPORTED_VERSION_REGEX='^(12|13)(\.|$)'
  source "$SCRIPT_DIR/../../Shared/deploy-linux.sh"
  deploy_linux_kubernetes "$@"
}

# Keep the file's main entry limited to orchestration.
main() {
  run_deployment "$@"
}

main "$@"
