#!/usr/bin/env bash
# 脚本自述：
# - 核心用途：卸载本机 Docker / Compose / K3s，运行时选择备份或永久删除数据。
# - 影响范围：两个部署路线与其它容器项目都会受影响；源码保留。
# - 运行提示：先回车阅读，再选数据策略，最后输入 YES；Ctrl+C 随时取消。

# 展示内置自述，无交互输入时停止，确认前不写文件。
show_script_intro_and_wait() {
  printf '\n啄木鸟维修平台 · Linux 完整反安装\n'
  printf '卸载 Docker / Compose / K3s；包含其它项目的容器、镜像、卷和集群。\n'
  printf '稍后选择先备份或永久删除数据；备份位于用户 RepairMarketplaceBackups 目录。\n'
  printf '日志写入系统临时目录 repair-uninstall-linux.*；Ctrl+C 取消。\n'
  [[ -t 0 ]] || { printf '请在交互式终端运行。\n' >&2; exit 1; }
  local answer=''
  IFS= read -r -p '已了解范围，按回车继续；Ctrl+C 取消：' answer || exit 1
}
# 从入口自身定位公共实现，不依赖终端当前目录。
load_cleanup_functions() {
  local entry_dir
  entry_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
  EXPECTED_OS_IDS='debian'
  source "$entry_dir/../../../Shared/uninstall-linux.sh" || exit 1
}
# 编排确认、依赖检查、数据策略、卸载和验证。
main() {
  show_script_intro_and_wait # 先展示范围并等待回车。
  load_cleanup_functions # 加载所有发行版共用实现。
  initialize_cleanup # 校验平台并启用审计日志。
  inspect_cleanup_targets # 列出软件包并检查非标准环境。
  confirm_cleanup_targets # 运行时选择数据策略并输入 YES。
  backup_linux_data # 保留模式先停止写入并验证数据归档。
  remove_k3s_runtime # 用官方卸载器删除本机集群。
  remove_docker_packages # 停服并卸载容器运行时软件包。
  remove_linux_residue # 清理固定安装路径与项目配置。
  verify_linux_cleanup # 验证工具已卸载并报告日志位置。
}

main "$@"
