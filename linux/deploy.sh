#!/bin/sh
# 在 Mac 上运行：把配置同步到 Linux 机器的 ~/.config/ibus/rime 并让 ibus-rime 重新部署。
#
# 用法: linux/deploy.sh 用户@主机
#
# 同步的是 Rime/（共用的配置，不含 Mac 专属的 squirrel.custom.yaml）加上
# linux/ibus_rime.custom.yaml。排除项与 README 里 Mac 的部署命令相同：
# 部署产物、同步目录、用户词典和运行时状态都不覆盖。
# 没有 --delete：Rime/ 里删掉的文件不会从目标目录消失，要手动挪到备份目录。
# 目标目录里被覆盖的旧文件挪到 ~/.config/ibus/rime.backup-<时间>（没有被覆盖的
# 文件时不会建这个目录）。
#
# 重新部署：ibus-rime 启动时只在配置比上次部署新时才部署，而 rsync 保留的是
# Mac 上的修改时间，所以先 touch 目标目录，再 ibus restart。部署发生在 Rime
# 引擎下次启动时（切到 Rime 输入源），日志在 /tmp/rime.ibus.*。
set -eu
if [ $# -ne 1 ]; then
  echo "usage: linux/deploy.sh USER@HOST" >&2
  exit 2
fi
host=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
dest=.config/ibus/rime
backup=../rime.backup-$(date +%Y%m%d-%H%M%S)

ssh "$host" "mkdir -p $dest"
rsync -a --backup --backup-dir="$backup" \
  --exclude=.DS_Store --exclude=/build/ --exclude=/sync/ --exclude=/trash/ \
  --exclude='*.userdb/' --exclude=/user.yaml --exclude=/installation.yaml \
  --exclude=/wubi98_ci.txt --exclude=/squirrel.custom.yaml \
  "$repo/Rime/" "$host:$dest/"
rsync -a --backup --backup-dir="$backup" \
  "$repo/linux/ibus_rime.custom.yaml" "$host:$dest/"
ssh "$host" "touch $dest && ibus restart"
echo "已同步到 $host:~/$dest 并重启 ibus；切到 Rime 后部署，日志见 /tmp/rime.ibus.*"
