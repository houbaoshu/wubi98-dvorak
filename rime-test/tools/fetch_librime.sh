#!/bin/sh
# macOS：下载 librime 1.16.0（a251145，与鼠须管 1.1.2 同版本）发布包，按记录的
# SHA-256 校验后解压到 vendor/，得到 vendor/dist（README“跑测试”第 1 步）。
# 已解压过（vendor/dist/lib/librime.1.dylib 在）就跳过；已下载且校验相同就不再下载。
# Linux 用系统的 librime，不需要这一步。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
name=rime-a251145-macOS-universal.tar.bz2
url=https://github.com/rime/librime/releases/download/1.16.0/$name
sum=e4c9a8767a456f2550f1242921b7656c6e6be088c89a921274bd5d4404f58b99
dl=$here/vendor/dl/$name

if [ -f "$here/vendor/dist/lib/librime.1.dylib" ]; then
  echo "vendor/dist 已在，跳过"
  exit 0
fi
mkdir -p "$here/vendor/dl"
if [ ! -f "$dl" ] || [ "$(shasum -a 256 "$dl" | awk '{print $1}')" != "$sum" ]; then
  echo "下载 $url"
  curl -fsSL -o "$dl.part" "$url"
  if [ "$(shasum -a 256 "$dl.part" | awk '{print $1}')" != "$sum" ]; then
    echo "error: $name 与记录的 SHA-256 不符，没有解压" >&2
    exit 1
  fi
  mv "$dl.part" "$dl"
fi
tar xjf "$dl" -C "$here/vendor"
echo "已解压到 vendor/dist"
