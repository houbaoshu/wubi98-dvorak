# wubi98-dvorak
- 改动先从 main 开分支，提交到分支后停下等审查，不自行合并或推送。
- Rime/ 是配置源头，~/Library/Rime 是部署目标。同步时从 Rime/ 复制；Rime/ 里删掉的文件，在 ~/Library/Rime 里挪到备份目录，不要直接删。不点重新部署。
- 提交前跑 rime-test/tools/check_dv.sh，全部通过。
- 五笔编码不凭记忆写，测试用的编码从词典里挑。
- 保留原作者文件的 CRLF 换行和 BOM。
