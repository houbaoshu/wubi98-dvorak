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

## Mac 安装

在一台新 Mac 上从零安装：克隆仓库（没有 git 时系统会提示安装命令行工具，也可以在 GitHub 上下载 zip 解压），
在仓库根目录运行：

```sh
mac/install.sh
```

脚本依次：

1. **鼠须管**：没装时下载官方 1.1.2 安装包（固定这个版本，不装最新版），按脚本里记录的 SHA-256 校验，
   缓存在 `~/Library/Caches/wubi98-dvorak/`。安装要管理员密码，脚本不代为安装，只打印命令
   （`sudo installer -pkg … -target /`，或 `open …` 用图形安装器），你装好后回到脚本按回车继续。
   已装了别的版本时只提示，不替换。
2. **字体**：`fonts/install-fonts.sh`（与 Linux 共用）下载 98WB 六个字体，校验后装到 `~/Library/Fonts`。
3. **同步**：`Rime/` 同步到 `~/Library/Rime`，排除项与下面“手动部署”相同。按校验和比较，只覆盖内容不同的文件，
   被覆盖的旧文件挪到 `~/Library/Rime.backup-<时间>`；目标里旧版 98 五笔留下的 `opencc/` 下 5 个文件
   和 `symbols.yaml`、`key_bindings.yaml`、`punctuation.yaml`（见“来源说明”）也挪到这里。
   没有被覆盖的文件时不建备份目录。
4. **重新部署**：鼠须管在运行时执行 `Squirrel --reload`，等于菜单里的“重新部署”；没在运行时，切到鼠须管时自动部署。

可以重复运行：鼠须管已装、安装包已下载、字体已装好且校验相同的都跳过，同步只动有变化的文件。

装完还要你在系统里确认：

- 系统设置 → 键盘 → 文字输入 → 输入法“编辑…”，列表里要有“鼠须管”。鼠须管的安装包装完会尝试自动启用；
  没有就点“+”在简体中文下添加，刚装完找不到时注销重新登录。
- 系统键盘布局保持“Dvorak”（英语）。
- 候选框里的拆分字根显示成方块时，重新登录一次。

先在临时目录里试同步和备份（目标不是 `~/Library/Rime` 时不触发重新部署）：

```sh
mac/install.sh --target /tmp/rime-try --font-dir /tmp/fonts-try
```

回滚：把 `~/Library/Rime.backup-<时间>` 里的文件拷回 `~/Library/Rime`，重新部署。

## 手动部署（Mac）

`mac/install.sh` 的第 3、4 步做的是同样的事，只是备份方式不同：脚本只备份被覆盖的文件，下面是整份备份。

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

macOS 和 Linux 上都能跑。macOS 上用与鼠须管 1.1.2 同版本的 librime 1.16.0（a251145）发布包，
带 librime-lua，不依赖系统里装的鼠须管；Linux 上用系统的 librime（见下面“Linux”一节）。

macOS：

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

Linux（Debian 13 实测）：装好 `g++ pkgconf librime-dev libxkbcommon-dev librime-plugin-lua`，
把仓库的 `Rime/`、`rime-test/` 复制过去（不用带 `.git`），同样跑 `rime-test/tools/check_dv.sh`。
`gen_dvorak_map` 换成 `gen_dvorak_map_xkb.c`，用 xkbcommon 实测 XKB 的 `us` 和 `us(dvorak)`，
输出与 macOS 版逐字节相同，所以映射表的核对照常生效。
想用系统的共享数据（ibus-rime 实际用的那份）跑，加 `RIME_TEST_SHARED=/usr/share/rime-data`。

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

## Linux（ibus-rime）

在 Debian 13 arm64 + GNOME 48（Wayland）+ ibus-rime 1.5.1 / librime 1.13.1 上跑通。
`Rime/` 是两边共用的配置；`squirrel.custom.yaml` 只用于 Mac，同步到 Linux 时排除；
Linux 专属的放在 `linux/`：`ibus_rime.custom.yaml`（候选竖排、编码不嵌入）、
`fontconfig/`（候选框字体回退）和 `deploy.sh`。下载安装 98WB 字体的 `fonts/install-fonts.sh` 与 Mac 共用。

1. 安装：

   ```sh
   sudo apt install --no-install-recommends ibus-rime librime-plugin-lua librime-bin libopencc-data rsync
   ```

   `libopencc-data` 提供繁简转换的 `s2t.json`（Debian 的 rime 包里没有）。

2. 在 Mac 的仓库根目录同步并重启 ibus（被覆盖的旧文件挪到 `~/.config/ibus/rime.backup-<时间>`）：

   ```sh
   linux/deploy.sh 用户@主机
   ```

   切到 Rime 时 ibus-rime 自动部署，日志在 `/tmp/rime.ibus.*`。
   脚本同时把 `linux/fontconfig/` 装到 `~/.config/fontconfig/conf.d/`，并在远端执行
   `fonts/install-fonts.sh` 安装字体（见第 4 步）。

3. 输入源：设置 → 键盘 → 输入源，依次是“英语（Dvorak）”和“中文（Rime）”。
   Rime 引擎的布局是 `default`，GNOME 会沿用前一个 XKB 布局，所以 Rime 收到的是德沃夏克字符，
   和 Mac 上 `keyboard_layout: Dvorak` 一样，`dvorak_remap.lua` 不用改。

4. 字体：本仓库不包含字体文件。`fonts/install-fonts.sh` 从原仓库
   [yanhuacuo/98wubi-unicode](https://github.com/yanhuacuo/98wubi-unicode) 的 release v1.0.0 附件
   `Ubuntu-22.04-LTS.tar.xz` 里取出 98WB-0、98WB-1、98WB-2、98WB-3、98WB-U、98WB-V 六个字体，
   按脚本里记录的 SHA-256 校验后装到 `~/.local/share/fonts/98WB`，再 `fc-cache -f`；已装好就不再下载。
   也可以在 Linux 上单独运行 `sh fonts/install-fonts.sh`。

   GNOME 的候选框由 gnome-shell 画，字体是 Shell 主题的 Cantarell，
   拆分字根和超集生僻字都靠 fontconfig 回退。gnome-shell 只在启动时读字体列表，
   **装了字体或改了 fontconfig 配置要注销重新登录**，否则候选框里还是方块。
   默认的回退顺序里 98WB 排得很后，BMP 私用区的字根（只有 98WB-V 有）会被 OpenSymbol
   画成不相干的符号；`linux/fontconfig/60-98wb-ibus-candidates.conf` 只对 gnome-shell 进程
   把 Noto Sans CJK SC、98WB-0（拆分字根，同 Mac 上 wubi98_ci 的注释字体）、98WB-V、98WB-U
   排到前面，其他程序不受影响。再装 `fonts-noto-cjk`，否则 98WB-1 会成为系统默认中文字体。

与 Mac 的差异：

- 不能按 App 设默认英文：ibus-rime 不把 App 信息传给 librime（没有 `client_app`），`app_options` 不生效。
- Debian 的 rime-prelude（`default.yaml` 0.40）把 Tab 绑成按词移动光标；鼠须管带的 0.50 是 Tab 选下一个候选。
- z 反查的候选注释在 Linux 上是“〔拆分 · 编码〕”，Mac 上只有编码（两边都与德沃夏克无关，原因未查）。
- 候选框字体不能按方案设：超集方案的拆分字根也用 98WB-0（Mac 上是 98WB-3），生僻字用 98WB-U/V。
- 切换开关（`Ctrl+Shift+F` 等）时 ibus-rime 不弹提示，只能从候选看出简繁；连按两次等于没切。
- 这几个快捷键会被 Rime 吃掉，App 自己的同名快捷键（如终端的 `Ctrl+Shift+F` 查找）用不了，Mac 上也一样。

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
- 98WB 字体（98WB-0、98WB-1、98WB-2、98WB-3、98WB-U、98WB-V）来自 98 五笔小组（yanhuacuo），
  原仓库 https://github.com/yanhuacuo/98wubi-unicode ，版权归原作者所有。
  本仓库不包含字体文件，`fonts/install-fonts.sh` 安装时从原仓库下载。
- `rime-test/shared/` 下的 `default.yaml`、`key_bindings.yaml`、`punctuation.yaml`、`symbols.yaml`
  取自 [rime/rime-prelude](https://github.com/rime/rime-prelude)（提交 db691d2，鼠须管 1.1.2 所带版本，LGPL-3.0）；
  `rime-test/shared/opencc/` 是鼠须管 1.1.2 里 `SharedSupport/opencc/` 的原样副本
  （[OpenCC](https://github.com/BYVoid/OpenCC)，Apache-2.0）。
- 改了 `Rime/rime.lua` 的 `rv_var`（关键字换成德沃夏克下敲词对应的引擎字母，`week`、`nl`、`jq` 改叫 `day`、`luna`、`term`），
  新增 `rv_show`；`Rime/lua/helper.lua` 帮助里的关键字改读 `rv_show`。各功能的实现没动。
- 本仓库新增的是德沃夏克映射（`Rime/lua/dvorak_remap.lua` 及各方案 custom.yaml 里的相关配置）、`mac/`、`linux/`、`fonts/` 里的安装脚本和 `rime-test/` 测试环境。
