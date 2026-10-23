#!/bin/sh
# 对每个 cases/*.keys：user-base 喂 QWERTY，user-dv 带 --dvorak，
# 各自隔离运行，逐键输出（stdout）必须完全一致。
# 若有同名的 <用例>.dv.keys，德沃夏克一侧改用它（物理键与 QWERTY 一侧不同，
# 如拼音反查里按德沃夏克字母敲）；这时去掉每键标题行里的键名、keycode 和
# mask 再比较，其余输出必须完全一致。
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
# 去掉标题行 "== [i] 键名 (keycode=... mask=...) 处理=是" 里与按了哪个键有关的部分
strip_keys() {
  sed 's/^== \[\([0-9]*\)\] .* 处理=/== [\1] 处理=/' "$1"
}

for keys in "$here"/cases/*.keys; do
  case $keys in *.dv.keys) continue ;; esac
  n=$(basename "$keys" .keys)
  dv_keys="$here/cases/$n.dv.keys"
  [ -f "$dv_keys" ] || dv_keys=$keys
  "$here/tools/run_case.sh" "$base" "$keys" \
    > "$here/logs/$n.base.out" 2> "$here/logs/$n.base.err"
  "$here/tools/run_case.sh" "$dv" "$dv_keys" --dvorak \
    > "$here/logs/$n.dv.out" 2> "$here/logs/$n.dv.err"
  errors=$(cat "$here/logs/$n.base.err" "$here/logs/$n.dv.err" |
           grep -cE '^[EF][0-9]' || true)
  if [ "$dv_keys" = "$keys" ] &&
     cmp -s "$here/logs/$n.base.out" "$here/logs/$n.dv.out"; then
    result="一致"
  elif [ "$dv_keys" != "$keys" ] &&
       [ "$(strip_keys "$here/logs/$n.base.out")" = \
         "$(strip_keys "$here/logs/$n.dv.out")" ]; then
    result="一致（换键，不比键名）"
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
