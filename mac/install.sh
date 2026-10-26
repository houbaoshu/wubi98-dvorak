#!/bin/sh
# 在一台 Mac 上从零装好这套输入法：鼠须管 1.1.2、98WB 字体，把 Rime/ 同步到
# ~/Library/Rime，再让鼠须管重新部署。可以重复运行，已装好的部分跳过。
#
# 用法（在仓库根目录）: mac/install.sh [--yes] [--target DIR] [--font-dir DIR]
#   --yes           需要装鼠须管时不等回车，直接运行 sudo installer（sudo 照常问密码）。
#                   用于 CI，那里 sudo 不要密码；平时不加。
#   --target DIR    同步到 DIR，默认 ~/Library/Rime。不是默认目录时不触发重新部署
#                   （鼠须管只部署 ~/Library/Rime），用来在临时目录里试同步和备份。
#   --font-dir DIR  字体装到 DIR，默认 ~/Library/Fonts。
#
# 1. 鼠须管：没装时下载官方 1.1.2 安装包（固定版本，不装最新版），按记录的 SHA-256
#    校验，缓存在 ~/Library/Caches/wubi98-dvorak/，已下载且校验相同就不再下载。
#    安装要管理员密码，默认脚本不代为执行，只打印命令，等你装好后继续；加 --yes 时直接运行。
#    已装了别的版本时只提示，不替换。环境变量 SQUIRREL_APP 可以换掉检查的路径，仅供测试。
# 2. 字体：fonts/install-fonts.sh（与 Linux 共用）。
# 3. 同步：排除项与 README 里手动部署的命令相同，部署产物、用户词典和运行时状态都不覆盖。
#    按校验和比较，只覆盖内容不同的文件（只差修改时间、权限的只同步属性，不备份）。
#    被覆盖的旧文件挪到 <目标>.backup-<时间>（没有被覆盖的文件时不会建这个目录）。
#    目标里旧版 98 五笔留下的、会让鼠须管崩溃或挡住新版的文件（见 README“来源说明”）
#    也挪到同一个备份目录。没有 --delete，其他只在目标里有的文件不动。
#    目标先解析成绝对路径，否则相对路径下 rsync 会把备份目录建在目标目录里面。
#    最后 touch 目标目录：rsync -a 保留的是 Rime/ 里的修改时间，可能早于上次部署的
#    var/last_build_time；鼠须管启动时检测改动只看修改时间，不 touch 就会跳过部署，
#    继续用旧的编译结果（linux/deploy.sh 同理）。
# 4. 重新部署：Squirrel --reload，与菜单里的“重新部署”相同。
set -eu

usage() {
  echo "usage: mac/install.sh [--yes] [--target DIR] [--font-dir DIR]" >&2
  exit 2
}

default_target=$HOME/Library/Rime
target=$default_target
font_dir=$HOME/Library/Fonts
yes=0
while [ $# -gt 0 ]; do
  case $1 in
    --target) [ $# -ge 2 ] || usage; target=$2; shift 2 ;;
    --font-dir) [ $# -ge 2 ] || usage; font_dir=$2; shift 2 ;;
    --yes) yes=1; shift ;;
    *) usage ;;
  esac
done

if [ "$(uname -s)" != Darwin ]; then
  echo "error: 这个脚本只用于 macOS；Linux 用 linux/deploy.sh" >&2
  exit 1
fi
repo=$(cd "$(dirname "$0")/.." && pwd)

squirrel_version=1.1.2
squirrel_app=${SQUIRREL_APP:-/Library/Input Methods/Squirrel.app}
pkg_url=https://github.com/rime/squirrel/releases/download/$squirrel_version/Squirrel-$squirrel_version.pkg
pkg_sum=614746013212937623d5bbab9901e9c43d1ec937aa32307d6b6092a05e308287
pkg=$HOME/Library/Caches/wubi98-dvorak/Squirrel-$squirrel_version.pkg

# 旧版 98 五笔安装包放进用户目录、本仓库已删掉的文件
stale='opencc/s2t.json opencc/STPhrases.ocd opencc/STCharacters.ocd opencc/jiayin.json opencc/jiayin.ocd
symbols.yaml key_bindings.yaml punctuation.yaml'

installed_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$squirrel_app/Contents/Info.plist" 2>/dev/null
}

pkg_ok() {
  [ -f "$pkg" ] && [ "$(shasum -a 256 "$pkg" | awk '{print $1}')" = "$pkg_sum" ]
}

echo "== 1/4 鼠须管"
if v=$(installed_version); then
  if [ "$v" = "$squirrel_version" ]; then
    echo "已装鼠须管 ${v}，跳过"
  else
    echo "warning: 已装鼠须管 ${v}，不是 ${squirrel_version}。脚本不替换；这套配置是按 $squirrel_version 测的。" >&2
  fi
else
  if pkg_ok; then
    echo "安装包已下载且校验相同：$pkg"
  else
    mkdir -p "$(dirname "$pkg")"
    echo "下载 $pkg_url"
    curl -fL --progress-bar -o "$pkg.part" "$pkg_url"
    if [ "$(shasum -a 256 "$pkg.part" | awk '{print $1}')" != "$pkg_sum" ]; then
      echo "error: 下载的安装包与记录的 SHA-256 不符，留在 $pkg.part，没有安装" >&2
      exit 1
    fi
    mv "$pkg.part" "$pkg"
    echo "已下载并校验：$pkg"
  fi
  echo
  if [ "$yes" = 1 ]; then
    echo "运行 sudo installer -pkg '$pkg' -target /"
    sudo installer -pkg "$pkg" -target /
  else
    echo "安装鼠须管需要管理员密码，请你手动完成（任选一种）："
    echo "  sudo installer -pkg '$pkg' -target /"
    echo "  open '$pkg'        # 图形安装器"
    if [ -t 0 ]; then
      printf '装好后按回车继续（也可以 Ctrl+C 退出，装好后重新运行本脚本）'
      read -r _
    else
      echo "装好后重新运行本脚本。"
      exit 1
    fi
  fi
  if ! v=$(installed_version); then
    echo "error: 还是没找到 ${squirrel_app}，装好后重新运行本脚本" >&2
    exit 1
  fi
  echo "已装鼠须管 $v"
fi

echo "== 2/4 98WB 字体"
sh "$repo/fonts/install-fonts.sh" "$font_dir"

mkdir -p "$target"
target=$(cd "$target" && pwd)
echo "== 3/4 同步 Rime/ 到 $target"
backup=$target.backup-$(date +%Y%m%d-%H%M%S)
for f in $stale; do
  if [ -e "$target/$f" ]; then
    mkdir -p "$(dirname "$backup/$f")"
    mv "$target/$f" "$backup/$f"
    echo "挪走旧版文件 $f"
  fi
done
rsync -a --checksum --itemize-changes --backup --backup-dir="$backup" \
  --exclude=.DS_Store --exclude=/build/ --exclude=/sync/ --exclude=/trash/ \
  --exclude='*.userdb/' --exclude=/user.yaml --exclude=/installation.yaml \
  --exclude=/wubi98_ci.txt \
  "$repo/Rime/" "$target/"
touch "$target"
if [ -d "$backup" ]; then
  echo "被覆盖或挪走的旧文件在 $backup"
else
  echo "没有被覆盖的文件，未建备份目录"
fi

echo "== 4/4 重新部署"
if [ "$target" != "$(cd "$default_target" 2>/dev/null && pwd)" ]; then
  echo "目标不是 ${default_target}，不触发重新部署"
elif pgrep -xq Squirrel; then
  "$squirrel_app/Contents/MacOS/Squirrel" --reload
  echo "已通知鼠须管重新部署，几秒后生效"
else
  echo "鼠须管没在运行，切换到鼠须管时会自动部署"
fi

cat <<'EOF'

还需要你在系统里确认：
- 系统设置 → 键盘 → 文字输入 → 输入法“编辑…”：列表里要有“鼠须管”（简体中文下）。
  没有就点“+”添加；刚装完鼠须管列表里找不到时，注销重新登录再试。
- 系统键盘布局保持“Dvorak”（英语）。鼠须管按德沃夏克布局接收按键
  （squirrel.custom.yaml 的 keyboard_layout），中文模式下由 dvorak_remap.lua 换回 QWERTY 键位打五笔。
- 候选框里的拆分字根显示成方块时，重新登录一次让字体生效。
EOF
