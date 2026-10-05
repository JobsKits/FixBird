#!/bin/zsh
# 脚本自述：
# - 核心用途：卸载 Docker Desktop / Minikube，并选择备份或永久清空数据。
# - 影响范围：两个部署路线、全部本地 Minikube 集群及其它容器项目。
# - 运行提示：回车阅读后选择数据策略，输入 YES 才卸载；Ctrl+C 取消。

# 内置自述必须先于任何文件写入或环境修改。
# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
show_script_intro_and_wait() {
  print '\n啄木鸟维修平台 · macOS 完整反安装' | jobs_intro_style body
  print '卸载 Docker Desktop / Minikube；包含其它项目的容器、镜像、卷和集群。' | jobs_intro_style body
  print '稍后选择先备份或永久删除数据；备份位于用户 RepairMarketplaceBackups 目录。' | jobs_intro_style body
  print '日志写入系统临时目录 repair-uninstall-macos.*；Ctrl+C 取消。' | jobs_intro_style body
  [[ -t 0 ]] || { print -u2 '请在 Terminal 中运行。'; exit 1; }
  local answer=''
  read -r 'answer?已了解范围，按回车继续；Ctrl+C 取消：' || exit 1
}
# 通过脚本路径加载公共实现，支持 Finder 双击及中文目录。
load_cleanup_functions() {
  SCRIPT_PATH="${(%):-%x}"
  SCRIPT_PATH="${SCRIPT_PATH:A}"
  source "${SCRIPT_PATH:h}/../../Shared/uninstall-macos.zsh" || exit 1
}
# 编排数据选择、备份、完整反安装及残留检查。
main() {
  show_script_intro_and_wait # 首先说明范围并等待回车。
  load_cleanup_functions # 加载公共反安装函数。
  initialize_cleanup # 检查环境并启用审计日志。
  confirm_cleanup_targets # 选择数据策略并用 YES 确认。
  backup_macos_data # 保留模式先制作停机数据备份。
  remove_minikube_runtime # 删除全部本地 profiles 和工具。
  remove_docker_desktop # 调用 Docker 官方卸载器。
  remove_macos_residue # 清理应用数据与项目部署配置。
  verify_macos_cleanup # 检查标准安装是否已清理。
}

main "$@"
