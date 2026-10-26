#!/bin/sh
# 编译 rime_dvtest 和 gen_dvorak_map。
#   macOS：链接 vendor/dist 里的 librime 发布包（rpath 指向 vendor/dist/lib，
#          相对可执行文件所在目录）；gen_dvorak_map 用 UCKeyTranslate。
#   Linux：链接系统的 librime（librime-dev）；gen_dvorak_map 用 xkbcommon
#          （gen_dvorak_map_xkb.c，libxkbcommon-dev），输出格式相同。
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$here/bin"
case $(uname -s) in
Darwin)
  clang++ -std=c++17 -O1 -Wall \
    -I"$here/vendor/dist/include" \
    "$here/tools/rime_dvtest.cc" \
    -L"$here/vendor/dist/lib" -lrime \
    -Wl,-rpath,@executable_path/../vendor/dist/lib \
    -o "$here/bin/rime_dvtest"
  # UCKeyTranslate 等 Carbon 接口已标记为过时，但仍可用。
  clang -O1 -Wall -Wno-deprecated-declarations \
    "$here/tools/gen_dvorak_map.c" -framework Carbon \
    -o "$here/bin/gen_dvorak_map"
  ;;
Linux)
  # shellcheck disable=SC2046
  g++ -std=c++17 -O1 -Wall $(pkg-config --cflags rime) \
    "$here/tools/rime_dvtest.cc" $(pkg-config --libs rime) \
    -o "$here/bin/rime_dvtest"
  # shellcheck disable=SC2046
  gcc -O1 -Wall $(pkg-config --cflags xkbcommon) \
    "$here/tools/gen_dvorak_map_xkb.c" $(pkg-config --libs xkbcommon) \
    -o "$here/bin/gen_dvorak_map"
  ;;
*)
  echo "error: unsupported OS: $(uname -s)" >&2
  exit 1
  ;;
esac
