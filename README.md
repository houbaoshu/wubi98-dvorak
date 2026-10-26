# 98 五笔 + 德沃夏克（鼠须管 / Rime）

[![安装测试](https://github.com/houbaoshu/wubi98-dvorak/actions/workflows/install-test.yml/badge.svg)](https://github.com/houbaoshu/wubi98-dvorak/actions/workflows/install-test.yml)

98 五笔 + 德沃夏克的 Rime 配置，支持 Mac（鼠须管）和 Linux（ibus-rime）。
系统键盘布局固定为德沃夏克：英文按德沃夏克打，中文按物理 QWERTY 键位打 98 五笔，不用来回切换系统输入源。

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/houbaoshu/wubi98-dvorak/main/install.sh | bash
```

把仓库克隆到 `~/.local/share/wubi98-dvorak`（已有就 `git pull --ff-only` 更新），再按系统运行
`mac/install.sh` 或 `linux/deploy.sh --local`。以后更新也是重新运行这一行。

### Mac

脚本会装鼠须管 1.1.2（要管理员密码时打印命令，等你装好按回车）、装字体、同步配置并重新部署。
没有 git 时会提示先运行 `xcode-select --install`。装完：

- 系统设置 → 键盘 → 文字输入 → 输入法“编辑…”，在简体中文下添加“鼠须管”（找不到就注销重新登录）。
- 键盘布局保持“Dvorak”（英语）。

### Linux（Debian 13）

先装软件包（脚本不代为执行 sudo；缺 git、rsync 时会打印这条命令），再运行上面那一行：

```sh
sudo apt install --no-install-recommends ibus-rime librime-plugin-lua librime-bin libopencc-data rsync fonts-noto-cjk git
```

然后在 设置 → 键盘 → 输入源 里依次放“英语（Dvorak）”和“中文（Rime）”，注销重新登录一次（候选框字体才生效）。

### 选项和备用方式

`bash -s --` 后面加参数：`--dir DIR` 换克隆位置，`--branch BRANCH` 用别的分支（测试用，默认 `main`）；
也可以用环境变量 `WUBI98_DVORAK_DIR`、`WUBI98_DVORAK_BRANCH`。其余参数在 Mac 上传给 `mac/install.sh`。

```sh
curl -fsSL https://raw.githubusercontent.com/houbaoshu/wubi98-dvorak/main/install.sh | bash -s -- --branch BRANCH
```

不想用 curl 管道，就自己克隆后运行平台脚本：

```sh
git clone https://github.com/houbaoshu/wubi98-dvorak.git
cd wubi98-dvorak
mac/install.sh            # Mac
linux/deploy.sh --local   # Linux，先装好上面的软件包
```

## 用法

- **方案**：含词（wubi98_ci，默认）、单字（wubi98_dz）、超集（wubi98_U）、拼音（py），``Ctrl+` `` 调出方案选单切换。
- **中英切换**：Shift。
- **单字、繁简**：`Ctrl+Shift+K` 切词/单，`Ctrl+Shift+F` 切简/繁（德沃夏克的 K、F）。只在当前会话有效；
  想保存就用方案选单里的开关。
- **z 拼音反查**：物理 Z 键进入，再按德沃夏克字母拼拼音。`; ' , .` 照旧是选第二、第三候选和标点。
- **/ 符号输入**：物理 `/` 键进入，再按德沃夏克字母敲代码（如 `/fs` 出分数）。
- **关键字**：中文模式下按德沃夏克字母敲 `date` 日期、`time` 时间、`day` 星期、`luna` 农历、`term` 节气、
  `next` 功能开关、`mode` 切方案、`help` 帮助。
- **默认英文的 App**（仅 Mac）：Terminal、Ghostty、Zed、访达、Spotlight。

## 安装脚本细节

**mac/install.sh**（可重复运行，已装好的、没变化的都跳过）：

1. 鼠须管没装时下载官方 1.1.2 安装包（固定版本，校验 SHA-256，缓存在 `~/Library/Caches/wubi98-dvorak/`），
   打印 `sudo installer …` 命令等你执行；已装别的版本只提示，不替换。
2. `fonts/install-fonts.sh`（与 Linux 共用）下载 98WB 六个字体，校验后装到 `~/Library/Fonts`。
3. `Rime/` 按校验和同步到 `~/Library/Rime`，被覆盖的旧文件和旧版 98 五笔遗留的会崩溃/挡路的文件
   （见“来源说明”）挪到 `~/Library/Rime.backup-<时间>`。
4. 鼠须管在运行就 `Squirrel --reload`；没运行时切到鼠须管会自动部署。

参数：`--yes` 直接运行 `sudo installer` 不等回车（CI 用）；`--target DIR`、`--font-dir DIR` 同步/装字体到别处，
用来试跑（目标不是 `~/Library/Rime` 时不重新部署）。

**linux/deploy.sh**：`--local` 在 Linux 本机运行；`linux/deploy.sh 用户@主机` 在 Mac 上经 ssh/rsync 同步到远端。
同步 `Rime/`（不含 Mac 专属的 `squirrel.custom.yaml`）和 `linux/ibus_rime.custom.yaml` 到 `~/.config/ibus/rime`，
旧文件挪到 `~/.config/ibus/rime.backup-<时间>`；装 `linux/fontconfig/` 和字体，然后 `ibus restart`。
切到 Rime 时自动部署，日志在 `/tmp/rime.ibus.*`。

回滚：把备份目录里的文件拷回去，重新部署。

## 手动部署（Mac）

```sh
cp -Rp ~/Library/Rime ~/Library/Rime.backup-$(date +%Y%m%d)
rsync -a --exclude=.DS_Store --exclude=/build/ --exclude=/sync/ --exclude=/trash/ \
  --exclude='*.userdb/' --exclude=/user.yaml --exclude=/installation.yaml \
  --exclude=/wubi98_ci.txt Rime/ ~/Library/Rime/
```

然后鼠须管菜单里“重新部署”。排除项保护用户词典、`user.yaml` 和部署产物；没有 `--delete`，
`Rime/` 里删掉的文件要手动挪走；`*.custom.yaml` 会被整个覆盖。目标里旧版 98 五笔的 `opencc/*.ocd`、
`symbols.yaml`、`key_bindings.yaml`、`punctuation.yaml` 要先挪走，否则繁简转换会让鼠须管崩溃。

## Linux 说明

在 Debian 13 arm64 + GNOME 48（Wayland）+ ibus-rime 1.5.1 / librime 1.13.1 上跑通。`Rime/` 两边共用，
Linux 专属的在 `linux/`。

- **Ubuntu 24.04 不能用**：librime-lua 太旧，没有 `KeyEvent(keycode, modifier)`，中文模式下的德沃夏克转换报错。
- `libopencc-data` 提供繁简转换的 `s2t.json`（Debian 的 rime 包里没有）；`fonts-noto-cjk` 防止 98WB-1 成为系统默认中文字体。
- Rime 引擎布局是 `default`，GNOME 沿用前一个 XKB 布局，所以 Rime 收到的是德沃夏克字符，和 Mac 一样。
- 候选框由 gnome-shell 画，只在启动时读字体，所以装字体或改 fontconfig 后要重新登录。
  `linux/fontconfig/60-98wb-ibus-candidates.conf` 只对 gnome-shell 把 Noto Sans CJK SC、98WB-0、98WB-V、98WB-U 排到前面，
  否则私用区字根会被 OpenSymbol 画成别的符号。

与 Mac 的差异：不能按 App 默认英文（ibus-rime 不传 `client_app`）；Tab 是按词移动光标（Debian 的 rime-prelude 0.40）；
z 反查注释多了拆分；候选框字体不能按方案设；切换开关时不弹提示，只能看候选判断简繁。
`Ctrl+Shift+F` 等快捷键两边都会被 Rime 吃掉，App 自己的同名快捷键用不了。

## 做法

- `squirrel.custom.yaml` 设 `keyboard_layout: com.apple.keylayout.Dvorak`，鼠须管收到德沃夏克字符；英文模式由
  `ascii_composer` 直接处理。
- 中文模式下 `lua/dvorak_remap.lua`（挂在 `ascii_composer` 之后，由三个五笔方案的 `*.custom.yaml` 挂载）
  把德沃夏克字符换成同一物理键的 QWERTY 字符。带 Ctrl/Alt/Command 的键不转换；z 反查和 / 符号输入时也不转换。
- 映射表由 `rime-test/bin/gen_dvorak_map` 调系统 `UCKeyTranslate` 实测生成。
- 关键字在 `Rime/rime.lua` 的 `rv_var` 里，按引擎实际收到的字母写（`date` 是 `hakd`），`rv_show` 是给人看的拼写。
- 三个方案删了 `KP_Decimal` 发 `period` 的绑定（会被再转换成 `e`）。

细节以 `Rime/lua/dvorak_remap.lua` 的注释为准。

## 跑测试

```sh
rime-test/tools/fetch_librime.sh   # macOS：下载 librime 1.16.0（与鼠须管 1.1.2 同版本）到 rime-test/vendor/
rime-test/tools/check_dv.sh        # 全部用例
```

Linux 上装 `g++ pkgconf librime-dev libxkbcommon-dev librime-plugin-lua` 后直接跑 `check_dv.sh`，用系统的 librime；
加 `RIME_TEST_SHARED=/usr/share/rime-data` 用系统共享数据。

`check_dv.sh` 从 `Rime/` 生成两个测试用户目录：`user-dv` 原样，`user-base` 去掉 dvorak_remap 作基线。
`rime-test/cases/<名字>.keys` 按 QWERTY 键名写，两侧各跑一遍，逐键输出必须一致、日志无 E/F 级错误。
可选的同名文件：`.dv.keys`（德沃夏克一侧改用它）、`.expect`（必须出现的行）、`.expect_re`（正则）、
`.mask`（比较前抹掉易变内容的 sed 脚本）、`.schema`（方案 id）。日志在 `rime-test/logs/`。单跑一个用例：

```sh
rime-test/tools/run_case.sh rime-test/user-dv rime-test/cases/01_four_code.keys --dvorak
```

## CI

`.github/workflows/install-test.yml` 在全新的 macOS（`macos-26`）和 Debian 13 容器里从零跑安装
（不 checkout，用 README 那一行 curl 命令：`install.sh` 克隆仓库后调用 `mac/install.sh --yes`、`linux/deploy.sh --local`；
Linux 上还先在没有 git 时跑一次，确认打印 apt 命令），核对版本、字体、配置、部署日志和 Lua 加载，最后跑 `check_dv.sh`。
没验证实际打字、候选框显示和在系统设置里添加输入源。

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
  - 改了 `Rime/rime.lua` 的 `rv_var`（关键字换成德沃夏克下敲词对应的引擎字母，`week`、`nl`、`jq` 改叫 `day`、`luna`、`term`），
    新增 `rv_show`；`Rime/lua/helper.lua` 帮助里的关键字改读 `rv_show`。各功能的实现没动。
- 98WB 字体（98WB-0、98WB-1、98WB-2、98WB-3、98WB-U、98WB-V）来自 98 五笔小组（yanhuacuo），
  原仓库 https://github.com/yanhuacuo/98wubi-unicode ，版权归原作者所有。
  本仓库不包含字体文件，`fonts/install-fonts.sh` 安装时从原仓库 release v1.0.0 的 `Ubuntu-22.04-LTS.tar.xz` 下载，
  按记录的 SHA-256 校验。
- `rime-test/shared/` 下的 `default.yaml`、`key_bindings.yaml`、`punctuation.yaml`、`symbols.yaml`
  取自 [rime/rime-prelude](https://github.com/rime/rime-prelude)（提交 db691d2，鼠须管 1.1.2 所带版本，LGPL-3.0）；
  `rime-test/shared/opencc/` 是鼠须管 1.1.2 里 `SharedSupport/opencc/` 的原样副本
  （[OpenCC](https://github.com/BYVoid/OpenCC)，Apache-2.0）。
- 本仓库新增的是德沃夏克映射（`Rime/lua/dvorak_remap.lua` 及各方案 custom.yaml 里的相关配置）、`mac/`、`linux/`、`fonts/` 里的安装脚本和 `rime-test/` 测试环境。
