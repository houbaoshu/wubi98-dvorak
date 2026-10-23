#!/bin/sh
# 编译 rime_dvtest，rpath 指向 vendor/dist/lib（相对可执行文件所在目录）。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$here/bin"
clang++ -std=c++17 -O1 -Wall \
  -I"$here/vendor/dist/include" \
  "$here/tools/rime_dvtest.cc" \
  -L"$here/vendor/dist/lib" -lrime \
  -Wl,-rpath,@executable_path/../vendor/dist/lib \
  -o "$here/bin/rime_dvtest"
