#!/bin/sh
# 在 Linux 上安装 98WB 字体：从 98 五笔小组（yanhuacuo）的原仓库下载，装到
# ~/.local/share/fonts/98WB，再 fc-cache -f。本仓库不包含字体文件。
#
# 用法（在 Linux 机器上）: sh install-fonts.sh
# linux/deploy.sh 会在 Mac 上通过 ssh 远程执行它。
#
# 来源：https://github.com/yanhuacuo/98wubi-unicode 的 release v1.0.0 附件
# Ubuntu-22.04-LTS.tar.xz，字体在包内 fonts/ 下。原仓库 master 根目录的
# 字体支持更新-20240131.7z.001/.002 里也是这六个文件，内容逐字节相同，
# 但解压要 7z，所以用 release 的 tar.xz。
# 下面的 SHA-256 是 2026-10-26 下载时算的；校验不过就不安装。
# 六个字体都已装好且校验相同时不再下载。
set -eu
url=https://github.com/yanhuacuo/98wubi-unicode/releases/download/v1.0.0/Ubuntu-22.04-LTS.tar.xz
dest=$HOME/.local/share/fonts/98WB
sums='7090a2ca4d8ddd0da44e860692c5844114816669eccd1756c9630bd860f76b64  98WB-0.otf
55eae64c47724f22236205810758c5d5c7852bd7ec95c442f627a5ed1b030b39  98WB-1.otf
e04a779479dd08740e7bededb0c9adbd9920abee6469a0881620966810140810  98WB-2.otf
75f4ae8a87aeef29f5aee90d66e831f11a0e9b5a8f7dc78fcd5f59ffae1f990e  98WB-3.otf
bd09facbcb6cef431ddcc1c445ee33ebac813a22993e7d505b4de07f7d07f972  98WB-U.otf
94f2f27fecf0c288d1785b9a11e111437427ac4e05c70c3a2dfcaef0526d91ff  98WB-V.otf'

check() {  # check DIR：DIR 里六个字体都在且校验相同
  (cd "$1" 2>/dev/null && echo "$sums" | sha256sum --check --status - 2>/dev/null)
}

if check "$dest"; then
  echo "98WB 字体已装好（$dest，校验相同），不再下载"
else
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "下载 $url"
  if command -v curl >/dev/null; then
    curl -fsSL -o "$tmp/fonts.tar.xz" "$url"
  else
    wget -q -O "$tmp/fonts.tar.xz" "$url"
  fi
  # 只解出六个字体
  tar -xJf "$tmp/fonts.tar.xz" -C "$tmp" $(echo "$sums" | awk '{print "fonts/" $2}')
  if ! check "$tmp/fonts"; then
    echo "error: 下载的字体与记录的 SHA-256 不符，没有安装" >&2
    (cd "$tmp/fonts" && echo "$sums" | sha256sum --check -) >&2 || true
    exit 1
  fi
  mkdir -p "$dest"
  for f in $(echo "$sums" | awk '{print $2}'); do
    install -m 644 "$tmp/fonts/$f" "$dest/$f"
  done
  echo "已安装到 $dest"
fi
fc-cache -f
echo "fc-cache 完成。GNOME 的候选框要注销重新登录后才会用上新字体。"
