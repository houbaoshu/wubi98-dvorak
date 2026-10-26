# wubi98-dvorak
- 改动先从 main 开分支，提交到分支后停下等审查，不自行合并或推送。
- Rime/ 是配置源头，~/Library/Rime 是部署目标。同步时从 Rime/ 复制；Rime/ 里删掉的文件，在 ~/Library/Rime 里挪到备份目录，不要直接删。不点重新部署。
- 仓库同时支持 Mac（鼠须管）和 Linux（ibus-rime）：共用配置放在 Rime/，Linux 专属的文件放在 linux/。改共用配置时要保证两个平台都不受影响。
- 提交前跑 rime-test/tools/check_dv.sh，全部通过。
- 五笔编码不凭记忆写，测试用的编码从词典里挑。
- 换行符不做要求（仓库里存 LF，Rime 两种都能读），但要保留原作者文件的 BOM。
