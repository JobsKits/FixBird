#!/usr/bin/env bash
# 脚本自述：只运行隔离函数测试，临时目录保存样本；不连接 daemon、不安装、不部署、不卸载。
set -eu

# 任何断言失败都以非零退出，方便本机和 CI 使用。
assert_rejected() {
  if "$@" > /dev/null 2>&1; then
    printf 'FAIL：应拒绝的调用通过：%s\n' "$*" >&2
    return 1
  fi
}
# 使用假命令验证本机目标、归属与备份停止门禁。
run_target_tests() {
  local audit_root audit_tmp valid_sha
  audit_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  audit_tmp="$(mktemp -d "${TMPDIR:-/tmp}/repair-deployment-tests.XXXXXX")"
  DEPLOYMENT_TEST_DIRECTORY="$audit_tmp"
  trap 'rm -f "$DEPLOYMENT_TEST_DIRECTORY/sample" "$DEPLOYMENT_TEST_DIRECTORY/receipt" "$DEPLOYMENT_TEST_DIRECTORY/removals"; rmdir "$DEPLOYMENT_TEST_DIRECTORY"' EXIT
  source "$audit_root/Deployment/Shared/components.sh"
  initialize_deployment_components "$audit_root"
  LOG_FILE=/dev/null
  unset DOCKER_HOST DOCKER_CONTEXT BUILDX_BUILDER BUILDKIT_HOST
  # 不调用实际 Docker：模拟已有 context 的元数据。
  docker() {
    case "$*" in
      'context show') printf 'fixture-context\n' ;;
      'context inspect fixture-context --format {{.Endpoints.docker.Host}}') printf '%s\n' "$MOCK_ENDPOINT" ;;
      *) printf '测试禁止实际 Docker 动作：%s\n' "$*" >&2; return 99 ;;
    esac
  }
  MOCK_ENDPOINT=unix:///var/run/docker.sock
  select_local_docker_target linux > /dev/null
  [[ "$DEPLOYMENT_DOCKER_HOST" == "$MOCK_ENDPOINT" ]]
  MOCK_ENDPOINT=ssh://fixture.invalid
  assert_rejected select_local_docker_target linux
  DOCKER_HOST=tcp://127.0.0.1:2375
  assert_rejected select_local_docker_target linux
  unset DOCKER_HOST
  MOCK_ENDPOINT=unix:///var/run/docker.sock
  BUILDX_BUILDER=remote-fixture
  assert_rejected select_local_docker_target linux
  unset BUILDX_BUILDER
  printf 'download-fixture' > "$audit_tmp/sample"
  valid_sha="$(deployment_sha256 "$audit_tmp/sample")"
  verify_deployment_download "$audit_tmp/sample" "$valid_sha"
  assert_rejected verify_deployment_download "$audit_tmp/sample" 0000000000000000000000000000000000000000000000000000000000000000
  curl() { return 22; }
  assert_rejected download_deployment_component MINIKUBE_DARWIN_ARM64 "$audit_tmp/sample"
  [[ "$(deployment_component MINIKUBE_VERSION)" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
  grep -Fx "ARG GO_VERSION=$(deployment_component GO_VERSION)" "$audit_root/Deployment/Docker/Shared/Dockerfile" >/dev/null
  grep -Fx "TIDB_IMAGE_TAG=$(deployment_component TIDB_VERSION)" "$audit_root/Deployment/Docker/Shared/.env.example" >/dev/null
  grep -F "image: pingcap/tidb:$(deployment_component TIDB_VERSION)" "$audit_root/Deployment/Kubernetes/Shared/workloads.yaml" >/dev/null
  awk -F= '/^[A-Z0-9_]+=/ { if (seen[$1]++) exit 1 } /_SHA256=/ { if (length($2) != 64 || $2 ~ /[^a-f0-9]/) exit 1 }' "$DEPLOYMENT_COMPONENTS_FILE"
  SCRIPT_DIR="$audit_root/Deployment/Kubernetes/Linux/Ubuntu"
  source "$audit_root/Deployment/Kubernetes/Shared/deploy-linux.sh"
  export K3S_URL=https://fixture.invalid:6443
  assert_rejected validate_k3s_install_environment
  unset K3S_URL
  validate_k3s_install_environment
  # 固定的 kubeconfig、节点列表与 machine-id 都来自替身。
  k3s_command() {
    case "$*" in
      config*) printf '%s' "$MOCK_K3S_SERVER" ;;
      'get nodes'*) printf '%s\n' "$MOCK_K3S_NODES" ;;
      *) return 99 ;;
    esac
  }
  cat() {
    if [[ "$*" == /etc/machine-id ]]; then printf 'fixture-machine\n'; else /bin/cat "$@"; fi
  }
  MOCK_K3S_SERVER=https://127.0.0.1:6443
  MOCK_K3S_NODES='fixture-node|fixture-machine'
  validate_local_k3s_cluster > /dev/null
  MOCK_K3S_NODES=$'fixture-node|fixture-machine\nother-node|other-machine'
  assert_rejected validate_local_k3s_cluster
  MOCK_K3S_NODES='other-node|other-machine'
  assert_rejected validate_local_k3s_cluster
  MOCK_K3S_SERVER=https://fixture.invalid:6443
  assert_rejected validate_local_k3s_cluster
  source "$audit_root/unDeployment/Shared/uninstall-linux.sh"
  # 所有 root 行为只接受测试 fixture，不会调用 sudo 或真实系统命令。
  cleanup_root() {
    case "$*" in
      'test -f /etc/docker/daemon.json') return 0 ;;
      'cat /etc/docker/daemon.json') printf '%s' "$MOCK_DAEMON_JSON" ;;
      env*) printf '%s' "$MOCK_LIVE_RESTORE" ;;
      'test -f /var/lib/repair-marketplace-deployment/owned-plugins.tsv') return 0 ;;
      'awk -F '*'-v path='*) awk -F '\t' -v path=/usr/local/lib/docker/cli-plugins/docker-buildx '$1 == path { hash=$2 } END { print hash }' "$audit_tmp/receipt" ;;
      awk*) awk -F '\t' '{ hashes[$1]=$2 } END { for (path in hashes) print path "\t" hashes[path] }' "$audit_tmp/receipt" ;;
      'test -L /usr/local/lib/docker/cli-plugins/docker-buildx') [[ "$MOCK_PLUGIN_LINK" == 1 ]] ;;
      'test -e /usr/local/lib/docker/cli-plugins/docker-buildx') [[ "$MOCK_PLUGIN_EXISTS" == 1 ]] ;;
      'test -e /usr/local/lib/docker/cli-plugins/docker-compose') return 1 ;;
      'rm -f -- /usr/local/lib/docker/cli-plugins/docker-buildx') MOCK_PLUGIN_EXISTS=0; printf 'buildx\n' >> "$audit_tmp/removals" ;;
      'rm -f -- /var/lib/repair-marketplace-deployment/owned-plugins.tsv') return 0 ;;
      *) printf '测试禁止真实 root 动作：%s\n' "$*" >&2; return 99 ;;
    esac
  }
  systemctl() { printf '%s' "$MOCK_SERVICE_COMMAND"; }
  pgrep() { [[ "$MOCK_WRITERS" == 1 ]]; }
  MOCK_SERVICE_COMMAND=''
  MOCK_LIVE_RESTORE=false
  MOCK_DAEMON_JSON='{"live-restore":true}'
  assert_rejected assert_no_live_restore
  MOCK_DAEMON_JSON='{}'
  MOCK_LIVE_RESTORE=true
  assert_rejected assert_no_live_restore
  MOCK_LIVE_RESTORE=false
  MOCK_SERVICE_COMMAND='dockerd --live-restore'
  assert_rejected assert_no_live_restore
  MOCK_SERVICE_COMMAND='dockerd'
  assert_no_live_restore
  MOCK_WRITERS=1
  assert_rejected assert_no_container_writers
  MOCK_WRITERS=0
  assert_no_container_writers
  pgrep() { return 2; }
  assert_rejected assert_no_container_writers
  deployment_sha256() { printf '%s\n' "$MOCK_PLUGIN_SHA"; }
  printf '/usr/local/lib/docker/cli-plugins/docker-buildx\t%s\n' "$valid_sha" > "$audit_tmp/receipt"
  MOCK_PLUGIN_EXISTS=1
  MOCK_PLUGIN_LINK=0
  MOCK_PLUGIN_SHA=mismatched
  assert_rejected verify_owned_linux_plugins
  assert_rejected remove_owned_linux_plugins
  [[ "$MOCK_PLUGIN_EXISTS" == 1 ]]
  MOCK_PLUGIN_SHA="$valid_sha"
  MOCK_PLUGIN_LINK=1
  assert_rejected verify_owned_linux_plugins
  MOCK_PLUGIN_LINK=0
  remove_owned_linux_plugins
  [[ "$MOCK_PLUGIN_EXISTS" == 0 && -s "$audit_tmp/removals" ]]
  if command -v zsh >/dev/null 2>&1; then
    # zsh 子进程只读取函数库，plutil / 硬件元数据全部由替身提供。
    zsh -s -- "$audit_root" <<'ZSH'
setopt ERR_EXIT PIPE_FAIL
source "$1/Deployment/Kubernetes/Shared/macos-deploy.zsh"
source "$1/Deployment/Docker/Shared/macos-functions.zsh"
LOG_FILE=/dev/null
sysctl() { print 1; }
uname() { print x86_64; }
detect_macos_arch
[[ "$MAC_CPU_ARCH" == arm64 ]]
plutil() {
  case "$*" in
    *Driver*) print "$MOCK_PROFILE_DRIVER" ;;
    *Nodes.0.Name*) [[ "$MOCK_PROFILE_NODES" -ge 1 ]] && print minikube ;;
    *Nodes.1.Name*) [[ "$MOCK_PROFILE_NODES" -gt 1 ]] && print worker ;;
    *) return 99 ;;
  esac
}
MOCK_PROFILE_DRIVER=docker
MOCK_PROFILE_NODES=1
validate_minikube_profile_metadata /fixture/config.json >/dev/null
MOCK_PROFILE_NODES=2
if validate_minikube_profile_metadata /fixture/config.json >/dev/null; then exit 1; fi
MOCK_PROFILE_NODES=0
if validate_minikube_profile_metadata /fixture/config.json >/dev/null; then exit 1; fi
MOCK_PROFILE_NODES=1
MOCK_PROFILE_DRIVER=vmware
if validate_minikube_profile_metadata /fixture/config.json >/dev/null; then exit 1; fi
ZSH
  else
    printf 'SKIP：未安装 zsh，macOS 芯片与 Minikube 元数据替身检查留给 macOS CI。\n'
  fi
  printf 'PASS：Docker 本机/远端/构建器、SHA256、K3s 单节点/归属、live-restore/writer、Buildx 所有权门禁（隔离测试）。\n'
}
# 此入口只调度无系统副作用的隔离测试。
main() {
  run_target_tests # 验证安全门禁，不连接真实服务。
}
main "$@"
