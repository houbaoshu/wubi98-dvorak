#!/bin/sh
# 隔离运行一个用例：把用户目录克隆到临时目录里再跑。会话期间对用户目录的
# 写入（用户词典 wubi98_ci.txt、user.yaml 等）随临时目录一起丢弃，
# 所以每次运行都从同一个状态开始。
#
# 用法: run_case.sh USER_DIR KEYFILE [rime_dvtest 的其他参数，如 --dvorak]
# 共享数据目录默认是 shared/，可用环境变量 RIME_TEST_SHARED 换掉
# （须与部署 USER_DIR 时用的一致，见 make_users.sh）。
# 逐键结果写 stdout，日志写 stderr。USER_DIR 应已部署（否则每次都要在
# 临时目录里重新部署）。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
if [ $# -lt 2 ]; then
  echo "usage: run_case.sh USER_DIR KEYFILE [rime_dvtest args...]" >&2
  exit 2
fi
user=$1
keys=$2
shift 2

tmp=$(mktemp -d "${TMPDIR:-/tmp}/rime_dvtest.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
# -p 保留修改时间，避免部署检查误判源文件已改；macOS 上 -c 在 APFS 上用克隆，
# 几乎不占空间。
case $(uname -s) in
Darwin) cp -Rpc "$user/" "$tmp/user" ;;
*) cp -Rp "$user/" "$tmp/user" ;;
esac
"$here/bin/rime_dvtest" --shared "${RIME_TEST_SHARED:-$here/shared}" --user "$tmp/user" \
  -f "$keys" "$@"
