#!/bin/sh
# 检查一份装好的用户目录（CI 用，见 .github/workflows/install-test.yml）：
#   1. rime_deployer --build USER_DIR SHARED_DIR USER_DIR/build 部署一次，
#      部署产物的位置与鼠须管、ibus-rime 相同。要求退出码 0、日志里没有 E/F 级，
#      且每个方案的 build/<方案>.schema.yaml 都生成了。
#      macOS 上用 vendor/dist 里的 rime_deployer（librime 与鼠须管 1.1.2 同版本，
#      先跑 fetch_librime.sh）；Linux 上用系统的（librime-bin）。
#   2. rime_deployer 只注册 core/dict/levers 模块，不加载插件，所以再用 rime_dvtest
#      在 USER_DIR 的临时克隆里开会话跑 cases/09_symbols_dv（德沃夏克一侧，靠
#      dvorak_remap.lua）：要求日志里有加载 lua 模块的记录、没有 E/F 级，
#      结果符合 09_symbols_dv.expect。需要先运行 build.sh。
# 用法: check_install.sh USER_DIR SHARED_DIR
# 会写 USER_DIR/build，不要对正在用的用户目录运行（那等于重新部署）。
set -eu
if [ $# -ne 2 ]; then
  echo "usage: check_install.sh USER_DIR SHARED_DIR" >&2
  exit 2
fi
here=$(cd "$(dirname "$0")/.." && pwd)
user=$1
shared=$2
logs=$(mktemp -d "${TMPDIR:-/tmp}/check_install.XXXXXX")
failed=0

echo "== rime_deployer 部署 ${user}（共享数据 ${shared}）"
case $(uname -s) in
Darwin)
  set -- env DYLD_LIBRARY_PATH="$here/vendor/dist/lib" "$here/vendor/dist/bin/rime_deployer" ;;
*)
  set -- rime_deployer ;;
esac
# glog 的日志文件写在 TMPDIR 下（rime.tools.*），也可能写 stderr，两处都查
mkdir -p "$logs/deploy"
if ! TMPDIR="$logs/deploy/" "$@" --build "$user" "$shared" "$user/build" \
     > "$logs/deploy.out" 2> "$logs/deploy.err"; then
  echo "error: rime_deployer 退出码非 0" >&2
  failed=1
fi
ls "$logs/deploy"
deploy_logs=$(find "$logs/deploy" -type f)
if [ -z "$deploy_logs" ] && [ ! -s "$logs/deploy.err" ]; then
  echo "error: 没找到 rime_deployer 的日志" >&2
  failed=1
fi
errors=$(cat "$logs/deploy.err" $deploy_logs | grep -E '^[EF][0-9]' | sort -u || true)
if [ -n "$errors" ]; then
  echo "error: 部署日志里有 E/F 级：" >&2
  echo "$errors" >&2
  failed=1
fi
echo "部署日志：$(cat "$logs/deploy.err" $deploy_logs | grep -E '^W[0-9]' | sort -u | grep -c . || true) 行 W 级（词典重复字等），E/F 级 $(echo "$errors" | grep -c . || true) 行"
# default.custom.yaml 的 schema_list 里每行一个 - {schema: 方案}
schemas=$(sed -n 's/^ *- *{ *schema: *\([A-Za-z0-9_]*\) *}.*/\1/p' "$user/default.custom.yaml")
if [ -z "$schemas" ]; then
  echo "error: 没从 default.custom.yaml 读到 schema_list" >&2
  failed=1
fi
for s in $schemas; do
  if [ -f "$user/build/$s.schema.yaml" ]; then
    echo "已生成 build/$s.schema.yaml"
  else
    echo "error: 没有生成 build/$s.schema.yaml" >&2
    failed=1
  fi
done

echo "== 会话：cases/09_symbols_dv（德沃夏克一侧）"
n=09_symbols_dv
if ! RIME_TEST_SHARED="$shared" "$here/tools/run_case.sh" "$user" \
     "$here/cases/$n.dv.keys" --dvorak > "$logs/$n.out" 2> "$logs/$n.err"; then
  echo "error: rime_dvtest 运行失败" >&2
  tail -20 "$logs/$n.err" >&2
  failed=1
fi
if grep -q "registering components from module 'lua'" "$logs/$n.err"; then
  echo "已加载 lua 模块：$(grep -m1 -E "loaded plugin: lua|registering components from module 'lua'" "$logs/$n.err" | sed 's/^.*\] //')"
else
  echo "error: 会话日志里没有加载 lua 模块的记录" >&2
  failed=1
fi
errors=$(grep -E '^[EF][0-9]' "$logs/$n.err" || true)
if [ -n "$errors" ]; then
  echo "error: 会话日志里有 E/F 级：" >&2
  echo "$errors" >&2
  failed=1
fi
grep -v '^#' "$here/cases/$n.expect" | while IFS= read -r line; do
  [ -n "$line" ] || continue
  if grep -qFx -- "$line" "$logs/$n.out"; then
    echo "符合：$line"
  else
    echo "error: 缺少：$line" >&2
    echo x >> "$logs/missing"
  fi
done
if [ -f "$logs/missing" ]; then
  failed=1
fi

if [ "$failed" = 0 ]; then
  rm -rf "$logs"
  echo "检查通过"
else
  echo "检查失败，日志在 $logs" >&2
fi
exit $failed
