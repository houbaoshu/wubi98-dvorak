#!/bin/sh
# 对每个 cases/*.keys：user-base 喂 QWERTY，user-dv 带 --dvorak，
# 各自隔离运行，逐键输出（stdout）必须完全一致。
# 结果写到 logs/<用例>.base.out|err 和 logs/<用例>.dv.out|err。
# 运行前后核对两个用户目录的用户词典没有被改动。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
base="$here/user-base"
dv="$here/user-dv"
mkdir -p "$here/logs"

for d in "$base" "$dv"; do
  name=$(basename "$d")
  if ! "$here/bin/rime_dvtest" --shared "$here/shared" --user "$d" \
       --deploy-only 2> "$here/logs/deploy-$name.log"; then
    echo "error: $name 部署失败，见 logs/deploy-$name.log" >&2
    exit 1
  fi
done

before=$(shasum "$base/wubi98_ci.txt" "$dv/wubi98_ci.txt")
failed=0
for keys in "$here"/cases/*.keys; do
  n=$(basename "$keys" .keys)
  "$here/tools/run_case.sh" "$base" "$keys" \
    > "$here/logs/$n.base.out" 2> "$here/logs/$n.base.err"
  "$here/tools/run_case.sh" "$dv" "$keys" --dvorak \
    > "$here/logs/$n.dv.out" 2> "$here/logs/$n.dv.err"
  errors=$(cat "$here/logs/$n.base.err" "$here/logs/$n.dv.err" |
           grep -cE '^[EF][0-9]' || true)
  if cmp -s "$here/logs/$n.base.out" "$here/logs/$n.dv.out"; then
    result="一致"
  else
    result="不一致"
    failed=1
  fi
  if [ "$errors" != 0 ]; then
    failed=1
  fi
  echo "${n}: ${result}（E/F 级日志 ${errors} 行）"
done
after=$(shasum "$base/wubi98_ci.txt" "$dv/wubi98_ci.txt")
if [ "$before" != "$after" ]; then
  echo "error: 运行期间用户目录里的 wubi98_ci.txt 被改动了" >&2
  failed=1
fi
exit $failed
