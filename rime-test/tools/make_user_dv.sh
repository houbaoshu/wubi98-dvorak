#!/bin/sh
# 从 user-base 重新生成 user-dv 并部署：
#   1. 核对 dv/lua/dvorak_remap.lua 里的映射表与系统布局实测一致；
#   2. 删除旧的 user-dv，复制 user-base（不含部署产物和运行时状态）；
#   3. 放入 dvorak_remap.lua，在 wubi98_ci.custom.yaml 里挂载 lua_processor；
#   4. 部署。
# 需要先运行 tools/build.sh。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
src="$here/user-base"
dst="$here/user-dv"
lua="$here/dv/lua/dvorak_remap.lua"

generated=$(awk '/^-- BEGIN GENERATED/{p=1;next} /^-- END GENERATED/{p=0} p' "$lua")
if [ "$generated" != "$("$here/bin/gen_dvorak_map" --lua)" ]; then
  echo "error: $lua 中的映射表与 gen_dvorak_map --lua 的输出不一致" >&2
  exit 1
fi

rm -rf "$dst"
rsync -a --exclude=/build/ --exclude=/user.yaml --exclude=/installation.yaml \
  --exclude='*.userdb/' "$src/" "$dst/"
cp -p "$lua" "$dst/lua/"

custom="$dst/wubi98_ci.custom.yaml"
# 追加的行要落在 patch 下：文件里只能有 patch: 这一个顶层键，且以换行结尾。
if [ "$(grep -c '^[^[:space:]#]' "$custom")" != 1 ] ||
   ! grep -q '^patch:' "$custom" ||
   [ -n "$(tail -c 1 "$custom")" ]; then
  echo "error: $custom 的结构不是预期的单个 patch: 段" >&2
  exit 1
fi
printf '%s\n' \
  '  # 德沃夏克 -> QWERTY 按物理位置重映射，挂在 ascii_composer 之后' \
  '  "engine/processors/@after 0": "lua_processor@*dvorak_remap"' >> "$custom"

mkdir -p "$here/logs"
if ! "$here/bin/rime_dvtest" --shared "$here/shared" --user "$dst" \
     --deploy-only 2> "$here/logs/deploy-user-dv.log"; then
  echo "error: user-dv 部署失败，见 logs/deploy-user-dv.log" >&2
  exit 1
fi
echo "user-dv 已生成并部署"
