# 98 五笔 + 德沃夏克（鼠须管 / Rime）

系统键盘布局固定为德沃夏克，只留鼠须管一个输入源：英文按德沃夏克打，
中文按物理 QWERTY 键位打 98 五笔，不用来回切换系统输入源。

## 用法

- **三个五笔方案 + 拼音**：含词（wubi98_ci，默认）、单字（wubi98_dz）、
  超集（wubi98_U）、拼音（py）。按 ``Ctrl+` `` 调出方案选单切换。
- **中英切换**：Shift（鼠须管默认）。
- **单字、繁简开关**：
  - `Ctrl+Shift+K` 切词/单，`Ctrl+Shift+F` 切简/繁。字母指德沃夏克布局下的 K、F，也就是按出这两个字母的那两个键。
  - 这两个快捷键只在当前会话有效，新会话回到“词”“简”。
  - 想保留选择就用方案选单（``Ctrl+` ``）里的开关，设置会保存。
- **z 拼音反查**：先按物理 Z 键进入反查，再按德沃夏克字母拼拼音。
  `; ' , .` 照旧是选第二、第三候选和标点。
- **/ 符号输入**：按物理 `/` 键进入，再按德沃夏克字母敲代码（拼音缩写，如 `/fs` 出分数）。
- **关键字**：中文模式下按德沃夏克字母敲这些词（不用先切英文），按空格或选字：
  `date` 日期、`time` 时间、`day` 星期、`luna` 农历、`term` 节气、`next` 功能开关（简繁、拆分等）、
  `mode` 切方案、`help` 帮助（列出这些关键字和其他功能）。
- **默认英文的 App**：Terminal、Ghostty、Zed、访达、Spotlight 新开会话默认英文模式，要打中文再按 Shift。

## 部署

1. 备份：

   ```sh
   cp -Rp ~/Library/Rime ~/Library/Rime.backup-$(date +%Y%m%d)
   ```

2. 在仓库根目录整份复制 `Rime/`：

   ```sh
   rsync -a --exclude=.DS_Store --exclude=/build/ --exclude=/sync/ --exclude=/trash/ \
     --exclude='*.userdb/' --exclude=/user.yaml --exclude=/installation.yaml \
     --exclude=/wubi98_ci.txt Rime/ ~/Library/Rime/
   ```

3. 鼠须管菜单里选“重新部署”；系统输入源只留鼠须管。

不会覆盖用户数据：

- 用户词典（`wubi98_ci.txt`、`*.userdb/`）、`user.yaml`（保存的方案和开关）、
  `installation.yaml` 和部署产物（`build/`、`sync/`）都在 `.gitignore` 里，新克隆的仓库里没有。
  但本机 `Rime/` 里可能留着旧的一份，所以命令里写了 `--exclude`，两种情况都安全。
- 只存在于 `~/Library/Rime` 的文件（如 `wubi98_dz.txt`、`py.userdb/`）本来就不在 `Rime/` 里，不会动。
- 没有 `--delete`：`Rime/` 里删掉的文件不会从 `~/Library/Rime` 消失，要手动挪到备份目录。
- `*.custom.yaml` 会被仓库里的版本整个覆盖，自己改过的以备份为准。

目标目录里若还有旧版 98 五笔的 `opencc/*.ocd`、`symbols.yaml`、`key_bindings.yaml`、
`punctuation.yaml`，先挪走（原因见“来源说明”），否则繁简转换会让鼠须管崩溃。

回滚：把备份拷回 `~/Library/Rime`，重新部署。

## 做法

- `squirrel.custom.yaml` 把 `keyboard_layout` 设为 `com.apple.keylayout.Dvorak`，
  鼠须管收到的是德沃夏克字符。
- 英文模式由排在最前面的 `ascii_composer` 处理，所以英文就是德沃夏克。
- 中文模式下，`lua/dvorak_remap.lua`（`lua_processor`，挂在 `ascii_composer` 之后）
  把德沃夏克字符换成同一物理键、同一 Shift 层的 QWERTY 字符再交给引擎。
  挂载是三个五笔方案 `*.custom.yaml` 里的一行：
  `"engine/processors/@after 0": "lua_processor@*dvorak_remap"`。
- 只转换无修饰键和只带 Shift 的键；带 Ctrl/Alt/Command 的键原样放行，所以快捷键认德沃夏克字母。
- z 反查和 / 符号输入时，字母原样放行，按德沃夏克字母敲；只看光标之前的编码。
- 三个方案的 `.schema.yaml` 删了 `KP_Decimal` 发 `period` 的绑定：重发的 `period` 会被再转换成 `e`。
- 映射表由 `rime-test/bin/gen_dvorak_map` 调系统 `UCKeyTranslate` 实测生成，不是手写的。
- 关键字在 `Rime/rime.lua` 开头的 `rv_var` 里，按引擎实际收到的字母写（`date` 是 `hakd`，
  换算用 `rime-test/tools/dvorak_map.tsv`）；`rv_show` 是显示给人看的德沃夏克拼写，`helper.lua` 的帮助用它。
  这 8 个编码不是 `wubi98_ci`/`dz`/`U`（含 extended）码表里的五笔编码；`day` 的 `hat` 只是 `虐待`（hatf）、
  `瞄向`（hatm）的前缀。
- 其他：方案依赖 `[py, wb_spelling]`；`zh_trad`、`single_char` 去掉 `reset: 0` 并列入
  `switcher/save_options`；`app_options` 里设 App 默认英文。

规则的细节以 `Rime/lua/dvorak_remap.lua` 的注释为准。

## 跑测试

只能在 macOS 上跑（`UCKeyTranslate`；`run_case.sh` 的 `cp -c` 依赖 APFS）。
用与鼠须管 1.1.2 同版本的 librime 1.16.0（a251145）发布包，带 librime-lua，不依赖系统里装的鼠须管。

1. 下载 [librime 1.16.0 发布页](https://github.com/rime/librime/releases/tag/1.16.0)
   的 `rime-a251145-macOS-universal.tar.bz2`，放到 `rime-test/vendor/dl/`，解压到 `rime-test/vendor/`：

   ```sh
   mkdir -p rime-test/vendor/dl
   tar xjf rime-test/vendor/dl/rime-a251145-macOS-universal.tar.bz2 -C rime-test/vendor
   ```

   解压后应有 `rime-test/vendor/dist/lib/librime.1.dylib` 和
   `rime-test/vendor/dist/lib/rime-plugins/librime-lua.dylib`。

2. 跑全部用例（需要 Xcode 命令行工具）：

   ```sh
   rime-test/tools/check_dv.sh
   ```

check_dv.sh 依次：`build.sh` 编译驱动 `rime_dvtest` 和 `gen_dvorak_map`；
`make_users.sh` 从 `Rime/` 生成两个测试用户目录并部署（`user-dv` 是原样，
`user-base` 去掉 dvorak_remap 的挂载行作基线，都不带用户词典）；
再对每个 `rime-test/cases/<名字>.keys` 在两侧各跑一遍，逐键输出必须一致，日志里没有 E/F 级错误。
所以测的总是 `Rime/` 当前的配置。

用例按 QWERTY 键名写：基线直接喂入，德沃夏克一侧带 `--dvorak`，先换成德沃夏克字符再喂入。
同名的可选文件：

- `<名字>.dv.keys`：德沃夏克一侧改用它（反查、符号输入要按德沃夏克字母敲）。
- `<名字>.expect`：每行（`#` 开头和空行除外）必须整行出现在两侧输出里，核对结果本身对不对。
- `<名字>.expect_re`：每行是扩展正则（`grep -E`），两侧输出里都要有一行匹配；日期、时间这类每次都变的内容用它核对格式。
- `<名字>.mask`：`sed -E` 脚本，比较两侧输出前先过一遍，抹掉易变内容（两侧是前后脚跑的，可能差一秒）。
- `<名字>.schema`：里面的方案 id 传给驱动的 `--schema`（默认 wubi98_ci）。

结果和日志在 `rime-test/logs/`。单独跑一个用例（先跑过一次 check_dv.sh 或 make_users.sh）：

```sh
rime-test/tools/run_case.sh rime-test/user-dv rime-test/cases/01_four_code.keys --dvorak
rime-test/tools/run_case.sh rime-test/user-dv /dev/null --dvorak a a a b   # 键直接写在命令行
```

run_case.sh 在临时克隆里跑，不改 `user-dv`；直接调用 `rime-test/bin/rime_dvtest` 会把会话写入留在用户目录里。

## 来源说明

- 码表源自 yanhuacuo（见 `Rime/wubi98_ci.schema.yaml`）。其余方案配置、lua 脚本来自 98 五笔资源库
  （http://www.98wubi.com ，https://github.com/98wb ，见 `Rime/lua/helper.lua`）。
  `Rime/` 取自我在用的鼠须管用户目录，与资源库当前的安装包不完全相同。
  原作者的码表、配置和 lua 版权归原作者所有。
- 为适配鼠须管 1.1.2（librime 1.16.0），对原作者的文件做了这些删改：
  - 删 `opencc/` 下的 `s2t.json`、`STPhrases.ocd`、`STCharacters.ocd`、`jiayin.json`、`jiayin.ocd`：
    旧版 OpenCC 的 `.ocd` 格式，librime 1.16.0 加载时崩溃；繁简转换改用鼠须管自带的 `s2t.json`。
  - 删 `symbols.yaml`、`key_bindings.yaml`、`punctuation.yaml`：rime-prelude 2019 年版的原样副本，会挡住鼠须管自带的新版。
  - 删 `hot_keys.yaml`、`hot_keys.custom.yaml` 和 `squirrel.custom.yaml` 里对它们的 `__include`
    （按 Windows 进程名写的 `app_options`，macOS 上不生效），以及没被引用的 `lua/multiline.lua`。
  - 去掉鼠须管不读的键：`style/fullscreen`、`style/preedit_type`、`keyboard_layout: default`。
  - `style/font_face` 键名多写的冒号已改正。
  - `lua/switcher.lua` 修了三处：数字键超出候选数时取到 nil 报错；`key.ctrl()` 改为 `key:ctrl()`；
    设了 `menu/alternative_select_keys` 时选择下标差 1。
- `rime-test/shared/` 下的 `default.yaml`、`key_bindings.yaml`、`punctuation.yaml`、`symbols.yaml`
  取自 [rime/rime-prelude](https://github.com/rime/rime-prelude)（提交 db691d2，鼠须管 1.1.2 所带版本，LGPL-3.0）；
  `rime-test/shared/opencc/` 是鼠须管 1.1.2 里 `SharedSupport/opencc/` 的原样副本
  （[OpenCC](https://github.com/BYVoid/OpenCC)，Apache-2.0）。
- 改了 `Rime/rime.lua` 的 `rv_var`（关键字换成德沃夏克下敲词对应的引擎字母，`week`、`nl`、`jq` 改叫 `day`、`luna`、`term`），
  新增 `rv_show`；`Rime/lua/helper.lua` 帮助里的关键字改读 `rv_show`。各功能的实现没动。
- 本仓库新增的是德沃夏克映射（`Rime/lua/dvorak_remap.lua` 及各方案 custom.yaml 里的相关配置）和 `rime-test/` 测试环境。
