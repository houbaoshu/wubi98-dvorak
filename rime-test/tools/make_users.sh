#!/bin/sh
# 从 ../Rime 重新生成两个测试用户目录并部署：
#   user-dv   = Rime/ 原样（已挂载 dvorak_remap）；
#   user-base = Rime/ 去掉 dvorak_remap 的挂载行，作为基线。
# 步骤：
#   1. 核对 Rime/lua/dvorak_remap.lua 里的映射表和 tools/dvorak_map.tsv
#      与系统布局实测一致；
#   2. 复制 Rime/（不含部署产物、运行时状态和用户词典 wubi98_ci.txt，
#      让结果不依赖本机输入历史）；
#   3. 在 default.custom.yaml 的 schema_list 末尾补上 wb_spelling：
#      副本里没有现成的 build/，不列出就不会编译，拼音反查会出错；
#   4. user-base 删掉挂载行；
#   5. 部署。
# 需要先运行 tools/build.sh。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
rime=$(cd "$here/../Rime" && pwd)
lua="$rime/lua/dvorak_remap.lua"
mount='"engine/processors/@after 0": "lua_processor@\*dvorak_remap"'

generated=$(awk '/^-- BEGIN GENERATED/{p=1;next} /^-- END GENERATED/{p=0} p' "$lua")
if [ "$generated" != "$("$here/bin/gen_dvorak_map" --lua)" ]; then
  echo "error: $lua 中的映射表与 gen_dvorak_map --lua 的输出不一致" >&2
  exit 1
fi
if ! "$here/bin/gen_dvorak_map" --tsv | cmp -s - "$here/tools/dvorak_map.tsv"; then
  echo "error: tools/dvorak_map.tsv 与 gen_dvorak_map --tsv 的输出不一致" >&2
  exit 1
fi
if [ "$(grep -c "^  $mount\$" "$rime/wubi98_ci.custom.yaml")" != 1 ]; then
  echo "error: Rime/wubi98_ci.custom.yaml 里没有恰好一行 dvorak_remap 挂载" >&2
  exit 1
fi

mkdir -p "$here/logs"
for name in base dv; do
  dst="$here/user-$name"
  rm -rf "$dst"
  rsync -a --exclude=/build/ --exclude=/sync/ --exclude=/trash/ \
    --exclude='*.userdb/' --exclude=/user.yaml --exclude=/installation.yaml \
    --exclude=/wubi98_ci.txt --exclude=.DS_Store \
    "$rime/" "$dst/"

  # schema_list 必须是文件的最后一段，追加的行才会落在它下面。
  custom="$dst/default.custom.yaml"
  if ! tail -n 1 "$custom" | grep -q '^    - {schema: [a-z0-9_]*}' ||
     [ -n "$(tail -c 1 "$custom")" ]; then
    echo "error: $custom 的最后一行不是 schema_list 的条目" >&2
    exit 1
  fi
  printf '    - {schema: wb_spelling}\r\n' >> "$custom"

  if [ "$name" = base ]; then
    grep -v "^  $mount\$" "$rime/wubi98_ci.custom.yaml" \
      > "$dst/wubi98_ci.custom.yaml"
  fi

  if ! "$here/bin/rime_dvtest" --shared "$here/shared" --user "$dst" \
       --deploy-only 2> "$here/logs/deploy-user-$name.log"; then
    echo "error: user-$name 部署失败，见 logs/deploy-user-$name.log" >&2
    exit 1
  fi
done
echo "user-base、user-dv 已从 Rime/ 生成并部署"
