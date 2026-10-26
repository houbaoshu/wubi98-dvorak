#!/bin/sh
# 一行命令安装的引导脚本：把仓库克隆（或更新）到本机，再交给对应平台的安装脚本。
# 安装本身全在 mac/install.sh、linux/deploy.sh 里，这里只管下载和分发。
#
#   curl -fsSL https://raw.githubusercontent.com/houbaoshu/wubi98-dvorak/main/install.sh | bash
#   curl -fsSL …/install.sh | bash -s -- [--dir DIR] [--branch BRANCH] [mac/install.sh 的参数]
#
#   --dir DIR        仓库放在 DIR，默认 ~/.local/share/wubi98-dvorak（环境变量 WUBI98_DVORAK_DIR）
#   --branch BRANCH  用 BRANCH 分支，默认 main（环境变量 WUBI98_DVORAK_BRANCH），用来测试
#   其余参数原样传给 mac/install.sh（如 CI 用的 --yes）；Linux 上 linux/deploy.sh --local 不接受别的参数。
#   环境变量 WUBI98_DVORAK_REPO 换掉克隆地址（CI 测 fork 的 PR 用），只在新克隆时起作用。
#
# 目录不存在时 git clone；已存在时切到指定分支，git pull --ff-only 更新（本地有改动、
# 分叉时 git 报错退出，不覆盖）。没有 git 时只打印要执行的安装命令，不代为执行 sudo。
#
# 全部内容包在函数里，最后一行才调用：curl 下载中途断开时，函数定义不完整，一行也不会执行。
# curl | bash 时脚本的标准输入是管道，所以平台脚本的标准输入改成 /dev/tty，
# 交互步骤（如 mac/install.sh 装鼠须管后按回车）照常读键盘；没有终端（CI）时用 /dev/null。

wubi98_dvorak_usage() {
  echo "usage: install.sh [--dir DIR] [--branch BRANCH] [mac/install.sh 的参数…]" >&2
  exit 2
}

# 缺 git 时打印安装方法并退出。Mac 的 /usr/bin/git 在没装命令行工具时只是个占位，
# 运行它会弹安装窗口，所以按 xcode-select -p 判断。
wubi98_dvorak_need_git() {
  case $1 in
    mac)
      if command -v git >/dev/null && { [ "$(command -v git)" != /usr/bin/git ] || xcode-select -p >/dev/null 2>&1; }; then
        return 0
      fi
      cat >&2 <<'EOF'
error: 没有 git。请先安装 Xcode 命令行工具（会弹出安装窗口）：
  xcode-select --install
装好后重新运行这条安装命令。
EOF
      exit 1 ;;
    linux)
      missing=
      for c in git rsync; do
        command -v $c >/dev/null || missing="$missing $c"
      done
      [ -z "$missing" ] && return 0
      cat >&2 <<EOF
error: 缺少${missing}。请先手动执行（Debian 13，同 README 的安装步骤；其他发行版装对应的包）：
  sudo apt install --no-install-recommends ibus-rime librime-plugin-lua librime-bin libopencc-data rsync fonts-noto-cjk git
装好后重新运行这条安装命令。
EOF
      exit 1 ;;
  esac
}

wubi98_dvorak_main() {
  set -eu
  dir=${WUBI98_DVORAK_DIR:-$HOME/.local/share/wubi98-dvorak}
  branch=${WUBI98_DVORAK_BRANCH:-main}
  repo_url=${WUBI98_DVORAK_REPO:-https://github.com/houbaoshu/wubi98-dvorak.git}
  # 解析完自己的参数后，"$@" 里只剩要传给 mac/install.sh 的
  n=$#
  while [ $n -gt 0 ]; do
    case $1 in
      --dir) [ $# -ge 2 ] || wubi98_dvorak_usage; dir=$2; shift 2; n=$((n - 2)) ;;
      --branch) [ $# -ge 2 ] || wubi98_dvorak_usage; branch=$2; shift 2; n=$((n - 2)) ;;
      -h|--help) wubi98_dvorak_usage ;;
      *) set -- "$@" "$1"; shift; n=$((n - 1)) ;;
    esac
  done

  case $(uname -s) in
    Darwin) os=mac ;;
    Linux) os=linux ;;
    *) echo "error: 只支持 macOS 和 Linux，这台是 $(uname -s)" >&2; exit 1 ;;
  esac
  if [ $os = linux ] && [ $# -gt 0 ]; then
    echo "error: Linux 上 linux/deploy.sh --local 不接受别的参数：$*" >&2
    exit 2
  fi
  wubi98_dvorak_need_git $os

  echo "== 获取仓库（${branch} 分支）到 $dir"
  if [ -e "$dir/.git" ]; then
    if [ "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" != "$branch" ]; then
      git -C "$dir" fetch origin
      git -C "$dir" checkout "$branch"
    fi
    if ! git -C "$dir" pull --ff-only origin "$branch"; then
      echo "error: $dir 更新失败（本地有改动或与远端分叉？），处理后重新运行，或用 --dir 换个位置" >&2
      exit 1
    fi
  elif [ -e "$dir" ] && [ -n "$(ls -A "$dir")" ]; then
    echo "error: $dir 已存在但不是 git 仓库，挪走后重新运行，或用 --dir 换个位置" >&2
    exit 1
  else
    mkdir -p "$(dirname "$dir")"
    git clone --branch "$branch" "$repo_url" "$dir"
  fi
  echo "当前提交 $(git -C "$dir" log -1 --format='%h %s')"

  if (exec </dev/tty) 2>/dev/null; then
    tty=/dev/tty
  else
    tty=/dev/null
  fi
  if [ $os = mac ]; then
    sh "$dir/mac/install.sh" "$@" <"$tty"
  else
    sh "$dir/linux/deploy.sh" --local <"$tty"
  fi
}

wubi98_dvorak_main "$@"
