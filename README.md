# 98 五笔 + 德沃夏克（鼠须管 / Rime）

在 macOS 上用德沃夏克（Dvorak）打英文，同时在鼠须管里按 QWERTY 键位打 98 五笔，
全程不用切换系统输入源。

## 要解决的问题

五笔的字根是按 QWERTY 键位排的，德沃夏克用户想打五笔，通常只能在
“系统德沃夏克布局”和“QWERTY 布局下的五笔”之间来回切换输入源。
切换有延迟，切换后偶尔还会错乱（按键按错布局解释），中英混打时尤其难受。

## 做法

只用鼠须管一个输入源，系统布局固定为德沃夏克：

- `squirrel.custom.yaml` 把 `keyboard_layout` 设为 `com.apple.keylayout.Dvorak`，
  鼠须管收到的是德沃夏克字符。
- `lua/dvorak_remap.lua` 这个 `lua_processor` 排在所有处理器之前，每个键都由它
  重发一次给引擎，后面的处理器（含 `ascii_composer`）只在重发那一层看到这个键。
  - 英文模式（ascii_mode）不转换，所以英文就是德沃夏克。
  - 中文模式下，把德沃夏克字符换成同一物理键、同一 Shift 层的 QWERTY 字符
    再重发。于是按物理 QWERTY 键位打五笔。
  - 只转换无修饰键和只带 Shift 的键；带 Ctrl/Alt/Command 等修饰的键、
    按键松开事件不转换，原样重发。
  - 重发期间下游合成再重发的键（如方案里 key_binder 把小键盘 `KP_Decimal`
    换成 `period`）不会被当成德沃夏克字符再转换一次。
  - 拼音反查（`z` 前缀）里按德沃夏克字母拼拼音：字母原样放行，
    `; ' , .` 等换算后是 QWERTY 字母的键也原样放行，其余符号（翻页等）照旧转换。
  - 转换后的键引擎不处理时（例如五笔不接收的 Shift+字母），
    应用收到的是原来的德沃夏克字符。
- 映射表由 `rime-test/tools/gen_dvorak_map` 调用系统 `UCKeyTranslate`，
  对 `com.apple.keylayout.US` 和 `com.apple.keylayout.Dvorak` 实测生成，不是手写的。

挂载只改了 `wubi98_ci` 方案（`wubi98_ci.custom.yaml` 里的一行）：

```yaml
  "engine/processors/@before 0": "lua_processor@*dvorak_remap"
```

早先的版本挂在 `@after 0`（`ascii_composer` 之后）；手工合并过那一行的，
要改成上面的 `@before 0`。

## 目录结构

```
Rime/                    Rime 用户目录的配置（部署到 ~/Library/Rime）
  lua/dvorak_remap.lua   德沃夏克 -> QWERTY 重映射（新增）
  wubi98_ci.custom.yaml  挂载上面的 lua_processor（新增一行）
  squirrel.custom.yaml   keyboard_layout 设为德沃夏克（改动）
  其余文件               98 五笔的方案、码表、lua 等；为适配鼠须管 1.1.2 删改过的
                         文件见“来源说明”
rime-test/               隔离的 librime 测试环境
  tools/rime_dvtest.cc   测试驱动：加载 librime，逐键喂入并打印上屏/编码区/候选
  tools/gen_dvorak_map.c 用系统键盘布局实测生成映射表
  tools/dvorak_map.tsv   gen_dvorak_map --tsv 的输出，驱动 --dvorak 时读取
  tools/build.sh         编译 rime_dvtest 和 gen_dvorak_map
  tools/make_users.sh    从 Rime/ 生成测试用户目录 user-base、user-dv 并部署
  tools/run_case.sh      在临时克隆的用户目录里运行一个用例
  tools/check_dv.sh      跑全部用例，比较基线与德沃夏克两侧
  cases/*.keys           用例（按键序列）
  shared/                共享数据目录：rime-prelude 的 default/key_bindings/
                         punctuation/symbols
```

不进仓库的（见 `.gitignore`）：`Rime/` 下的部署产物 `build/`、`sync/`、`trash/`、
`*.userdb/`、`user.yaml`、`installation.yaml` 和用户词典 `wubi98_ci.txt`；
`rime-test/` 下的 `vendor/`（librime 发布包）、`bin/`、`logs/`、`user-*/`。

## 部署到 ~/Library/Rime

前提：已装好鼠须管和 98 五笔配置。

1. 先备份现有配置：

   ```sh
   cp -Rp ~/Library/Rime ~/Library/Rime.backup
   ```

2. 已有 98 五笔配置时，只需要放入德沃夏克相关的三个文件：

   ```sh
   cp Rime/lua/dvorak_remap.lua ~/Library/Rime/lua/
   cp Rime/wubi98_ci.custom.yaml Rime/squirrel.custom.yaml ~/Library/Rime/
   ```

   如果你本地改过这两个 yaml，请手工合并：`wubi98_ci.custom.yaml` 的 `patch:`
   下加上面那行挂载，`squirrel.custom.yaml` 的 `patch:` 下设
   `"keyboard_layout": com.apple.keylayout.Dvorak`。

3. 在鼠须管菜单里选“重新部署”。
4. 系统设置里输入源保留鼠须管即可，打英文用鼠须管的英文模式。

回滚：从备份里拷回两个 yaml，删掉 `~/Library/Rime/lua/dvorak_remap.lua`，再重新部署。

## 跑测试

测试只能在 macOS 上运行：映射表由系统键盘布局接口（Carbon 的
`UCKeyTranslate`）实测生成，`run_case.sh` 克隆用户目录用的 `cp -c` 依赖 APFS。

测试环境不依赖系统里安装的鼠须管，使用与鼠须管 1.1.2 相同版本的
librime 1.16.0（a251145）官方发布包，带 librime-lua 插件。发布包不在仓库里，
需要按下面第 1 步另外下载。

1. 下载 [librime 1.16.0 发布页](https://github.com/rime/librime/releases/tag/1.16.0)
   里的 `rime-a251145-macOS-universal.tar.bz2`，解压到 `rime-test/vendor/`：

   ```sh
   mkdir -p rime-test/vendor/dl
   # 把下载的文件放到 rime-test/vendor/dl/ 后：
   tar xjf rime-test/vendor/dl/rime-a251145-macOS-universal.tar.bz2 -C rime-test/vendor
   ```

   解压后应有 `rime-test/vendor/dist/lib/librime.1.dylib` 和
   `rime-test/vendor/dist/lib/rime-plugins/librime-lua.dylib`。

2. 编译（需要 Xcode 命令行工具）：

   ```sh
   rime-test/tools/build.sh
   ```

3. 跑全部用例：

   ```sh
   rime-test/tools/check_dv.sh
   ```

check_dv.sh 先调用 make_users.sh，每次都从 `Rime/` 重新生成两个测试用户目录，
所以测的总是 `Rime/` 当前的配置：

- `user-dv`：`Rime/` 原样；
- `user-base`：`Rime/` 去掉 dvorak_remap 的挂载行，作为基线。

两者都不带用户词典。拼音反查要用的 `wb_spelling` 由 `wubi98_ci.custom.yaml`
声明为方案依赖，部署时一并编译，不需要另外处理。
make_users.sh 还会核对 lua 里的映射表和 `dvorak_map.tsv` 与系统布局实测一致。

每个用例 `cases/<名字>.keys` 按 QWERTY 键名写：基线一侧直接喂入；
德沃夏克一侧带 `--dvorak`，先把每个物理键换成德沃夏克字符再喂入，
模拟系统布局为德沃夏克时鼠须管收到的字符。两侧逐键输出必须完全一致，
且日志里没有 E/F 级错误。若有同名的 `<名字>.dv.keys`（拼音反查里按德沃夏克字母敲，
物理键不同），德沃夏克一侧改用它，比较时去掉每键标题行里的键名和 keycode。
每个用例都在用户目录的临时克隆里运行，互不影响。结果和日志在 `rime-test/logs/`。

单独跑一个用例或几个键：

```sh
rime-test/tools/run_case.sh rime-test/user-dv rime-test/cases/01_four_code.keys --dvorak
rime-test/bin/rime_dvtest --shared rime-test/shared --user rime-test/user-dv --dvorak a a a b
```

## 来源说明

- 码表源自 yanhuacuo（见 `Rime/wubi98_ci.schema.yaml` 的说明）。
- 其余方案配置、lua 脚本等来自 98 五笔资源库
  （官网 http://www.98wubi.com ，项目 https://github.com/98wb ，
  见 `Rime/lua/helper.lua`）。`Rime/` 取自我在用的鼠须管用户目录，
  与资源库当前发布的安装包版本不完全相同。除下面列出的德沃夏克改动外，
  为适配鼠须管 1.1.2（librime 1.16.0）对原作者的文件做了这些删改：
  - 删除 `opencc/` 下的 `s2t.json`、`STPhrases.ocd`、`STCharacters.ocd`、
    `jiayin.json`、`jiayin.ocd`：旧版 OpenCC 的 `.ocd` 格式，librime 1.16.0
    加载时会崩溃；繁简转换改用鼠须管自带的 `s2t.json`。
  - 删除 `symbols.yaml`、`key_bindings.yaml`、`punctuation.yaml`：
    rime-prelude 2019 年版的原样副本，放在用户目录里会挡住鼠须管自带的新版。
  - 删除 `hot_keys.yaml`、`hot_keys.custom.yaml`，以及 `squirrel.custom.yaml`
    里引用它们的 `__include`：按 Windows 进程名（`.exe`）写的 app_options，
    在 macOS 上永远不生效。
  - 删除没有被引用的 `lua/multiline.lua`。
  - 去掉鼠须管不读的键：三个 `wubi98_*.custom.yaml` 里的 `style/fullscreen`、
    `style/preedit_type`（小狼毫专用），`default.custom.yaml` 和
    `wubi98_ci.custom.yaml` 里的 `keyboard_layout: default`。
    `style/horizontal` 鼠须管也不读，但 `lua/new_spelling.lua` 会读，所以保留。
  - `wubi98_ci.custom.yaml`、`wubi98_U.custom.yaml` 的 `style/font_face`
    键名原来多写了冒号（`"style/font_face:"`），已改正；
    `wubi98_ci.custom.yaml` 声明 `schema/dependencies: [py, wb_spelling]`。
  - `lua/switcher.lua` 修了三处：数字键超出候选数时取到 nil 报错；
    `key.ctrl()` 改为 `key:ctrl()`；设了 `menu/alternative_select_keys` 时
    选择下标差 1。
- `rime-test/shared/` 取自 [rime/rime-prelude](https://github.com/rime/rime-prelude)
  （提交 db691d2，LGPL-3.0）。
- 本仓库新增的是德沃夏克映射（`Rime/lua/dvorak_remap.lua`、
  `Rime/wubi98_ci.custom.yaml` 里的挂载行、`Rime/squirrel.custom.yaml` 的
  `keyboard_layout`）和 `rime-test/` 测试环境。
- 原作者的码表、配置和 lua 版权归原作者所有，本仓库新增部分为德沃夏克映射和测试环境。
