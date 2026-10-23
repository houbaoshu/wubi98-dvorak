#!/bin/sh
# 对每个 cases/*.keys：user-base 喂 QWERTY，user-dv 带 --dvorak，
# 各自隔离运行，逐键输出（stdout）必须完全一致。
# 若有同名的 <用例>.dv.keys，德沃夏克一侧改用它（物理键与 QWERTY 一侧不同，
# 如拼音反查里按德沃夏克字母敲）；这时去掉每键标题行里的键名、keycode 和
# mask 再比较，其余输出必须完全一致。
# 若有同名的 <用例>.expect，其中每行（# 开头的除外）还必须作为整行出现在
# 两侧的输出里，用来核对结果本身对不对（两侧一致但都错时也能发现）。
# 结果写到 logs/<用例>.base.out|err 和 logs/<用例>.dv.out|err。
# 先用 build.sh 重新编译驱动和生成器（改过 tools/ 下的源码也不会测到旧程序），
# 再用 make_users.sh 从 ../Rime 重新生成两个用户目录，测的总是 Rime/ 当前的配置；
# 运行前后核对两个用户目录没有被用例改动（用例应在临时克隆里运行）。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
base="$here/user-base"
dv="$here/user-dv"

"$here/tools/build.sh"
"$here/tools/make_users.sh"

snapshot() {
  (cd "$here" && find user-base user-dv -path '*/build' -prune -o -type f \
     -exec shasum {} + | sort)
}
before=$(snapshot)
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
  # 两侧都跑，各自记退出码，日志都是这一轮的。某一侧运行出错（如键名写错）
  # 时报出用例名和出错的一侧，继续跑其余用例。
  bad=""
  "$here/tools/run_case.sh" "$base" "$keys" \
    > "$here/logs/$n.base.out" 2> "$here/logs/$n.base.err" ||
    bad="$bad logs/$n.base.err"
  "$here/tools/run_case.sh" "$dv" "$dv_keys" --dvorak \
    > "$here/logs/$n.dv.out" 2> "$here/logs/$n.dv.err" ||
    bad="$bad logs/$n.dv.err"
  if [ -n "$bad" ]; then
    echo "${n}: 运行失败，见$bad"
    failed=1
    continue
  fi
  errors=$(cat "$here/logs/$n.base.err" "$here/logs/$n.dv.err" |
           grep -cE '^[EF][0-9]' || true)
  result="不一致"
  if [ "$dv_keys" = "$keys" ]; then
    cmp -s "$here/logs/$n.base.out" "$here/logs/$n.dv.out" && result="一致"
  else
    [ "$(strip_keys "$here/logs/$n.base.out")" = \
      "$(strip_keys "$here/logs/$n.dv.out")" ] && result="一致（换键，不比键名）"
  fi
  if [ "$result" = "不一致" ]; then
    failed=1
  fi
  expect="$here/cases/$n.expect"
  if [ -f "$expect" ]; then
    missing=$(grep -v '^#' "$expect" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      for out in "$here/logs/$n.base.out" "$here/logs/$n.dv.out"; do
        if ! grep -qFx -- "$line" "$out"; then
          echo "$line"
          break
        fi
      done
    done)
    if [ -n "$missing" ]; then
      result="${result}，不符合 $n.expect，缺少：$(echo "$missing" | sed 's/^ *//' | paste -sd ' ' -)"
      failed=1
    else
      result="${result}，符合 $n.expect"
    fi
  fi
  if [ "$errors" != 0 ]; then
    failed=1
  fi
  echo "${n}: ${result}（E/F 级日志 ${errors} 行）"
done
if [ "$before" != "$(snapshot)" ]; then
  echo "error: 运行期间用户目录被改动了" >&2
  failed=1
fi
exit $failed
