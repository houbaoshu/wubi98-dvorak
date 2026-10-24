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
- 英文模式（ascii_mode）由排在最前面的 `ascii_composer` 直接处理，
  所以英文就是德沃夏克。
- 中文模式下，`lua/dvorak_remap.lua` 这个 `lua_processor` 紧跟在
  `ascii_composer` 之后：把德沃夏克字符换成同一物理键、同一 Shift 层的
  QWERTY 字符，再交给引擎重新处理。于是按物理 QWERTY 键位打五笔。
  - 只转换无修饰键和只带 Shift 的键；带 Ctrl/Alt/Command 等修饰的键、
    按键松开事件原样放行。
  - 下游绑定若把放行的键换成映射表里的字符再重发，重发的键会被再转换一次。
    所以删掉了 `wubi98_ci`、`wubi98_dz`、`wubi98_U` 三个 `.schema.yaml` 里小键盘 `KP_Decimal` 发 `period`
    的绑定（否则编码中按小键盘小数点会变成编码 `e`）；编码中按小键盘小数点
    现在交给应用。
  - 拼音反查（`z` 前缀）里按德沃夏克字母拼拼音：字母原样放行；
    `; ' , .` 及其 Shift 层（换算后是 QWERTY 字母）也原样放行，分别是选第二、
    第三候选和标点；其余符号（翻页等）照旧转换。
  - 符号输入（`/` 加字母，如 `/fs` 出分数，代码是拼音缩写）同样按德沃夏克字母敲，
    哪些键原样放行与拼音反查相同。敲了数字或其他符号之后（如 `/1`），
    后面的字母照旧转换。
  - 进入反查的 `z`、进入符号输入的 `/` 是在编码区为空时按物理 Z 键、物理 / 键
    转换出来的，不受上面两条影响。
  - 这两处都只看光标之前的编码：光标移到 `z` 或 `/` 之前再打字母，
    字母进的是五笔，照旧转换。
  - 引擎不处理的键交还给应用，应用收到的是原来的德沃夏克字符。
- 映射表由 `rime-test/bin/gen_dvorak_map`（源码 `rime-test/tools/gen_dvorak_map.c`）
  调用系统 `UCKeyTranslate`，
  对 `com.apple.keylayout.US` 和 `com.apple.keylayout.Dvorak` 实测生成，不是手写的。

挂载只改了 `wubi98_ci`、`wubi98_dz`、`wubi98_U` 三个方案（各自 custom.yaml 里的一行）：

```yaml
  "engine/processors/@after 0": "lua_processor@*dvorak_remap"
```

另外三个方案的 `.schema.yaml` 里各删了小键盘小数点的一行绑定，见上。三个方案都同样声明了
`schema/dependencies: [py, wb_spelling]`，并去掉 `zh_trad`、`single_char` 的
`reset: 0`（`switches/@1`、`switches/@6`，三个方案下标相同），
`default.custom.yaml` 的方案列表是 wubi98_ci、wubi98_dz、wubi98_U、py。

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
  tools/build.sh         编译 rime_dvtest 和 gen_dvorak_map 到 bin/
  tools/make_users.sh    从 Rime/ 生成测试用户目录 user-base、user-dv 并部署
  tools/run_case.sh      在临时克隆的用户目录里运行一个用例
  tools/check_dv.sh      编译、生成用户目录，跑全部用例，比较基线与德沃夏克两侧
  tools/compile_flags.txt、tools/.clangd
                         编辑器（clangd）用的编译参数，C/C++ 分开
  cases/*.keys           用例（按键序列）；可选 *.dv.keys、*.expect，见“跑测试”
  shared/                共享数据目录：rime-prelude 的 default/key_bindings/
                         punctuation/symbols
  shared/opencc/         鼠须管 1.1.2 自带的 OpenCC 数据（繁简转换）
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

2. 已有 98 五笔配置时，只需要放入德沃夏克相关的六个文件。前提是现有配置已经
   做过“来源说明”里适配鼠须管 1.1.2 的清理。没做过的（例如直接装的旧版
   98 五笔），先把冲突的文件挪到备份目录，有哪个挪哪个：

   ```sh
   mkdir -p ~/Library/Rime.migrate-backup/opencc
   (cd ~/Library/Rime &&
    for f in opencc/s2t.json opencc/STPhrases.ocd opencc/STCharacters.ocd \
             opencc/jiayin.json opencc/jiayin.ocd \
             symbols.yaml key_bindings.yaml punctuation.yaml; do
      if [ -e "$f" ]; then mv "$f" ~/Library/Rime.migrate-backup/"$f"; fi
    done)
   ```

   - `opencc/` 下这几个是旧版 OpenCC 格式（`.ocd`），留着的话，繁简转换
     （Ctrl+Shift+4）后第一次出候选时鼠须管就会崩溃；挪走后 `s2t.json`
     改用鼠须管自带的。
   - 三个 yaml 是 rime-prelude 的旧副本，会挡住鼠须管自带的新版；
     测试和符号输入的代码以新版为准。

   然后复制六个文件：

   ```sh
   cp Rime/lua/dvorak_remap.lua ~/Library/Rime/lua/
   cp Rime/default.custom.yaml Rime/squirrel.custom.yaml \
      Rime/wubi98_ci.custom.yaml Rime/wubi98_dz.custom.yaml \
      Rime/wubi98_U.custom.yaml ~/Library/Rime/
   ```

   如果你本地改过这几个 yaml，请手工合并：`wubi98_ci.custom.yaml`、
   `wubi98_dz.custom.yaml`、`wubi98_U.custom.yaml` 的 `patch:` 下加上面那行挂载
   （以及依赖、`switches/@1`、`switches/@6`，照仓库里的文件），
   `default.custom.yaml` 的 `patch:` 下把 `schema_list` 设为 wubi98_ci、
   wubi98_dz、wubi98_U、py，`squirrel.custom.yaml` 的 `patch:` 下设
   `"keyboard_layout": com.apple.keylayout.Dvorak`。

   再删掉三个方案 `.schema.yaml` 里小键盘小数点的绑定：

   ```sh
   sed -i '' '/{accept: KP_Decimal, send: period, when: composing}/d' \
     ~/Library/Rime/wubi98_ci.schema.yaml \
     ~/Library/Rime/wubi98_dz.schema.yaml ~/Library/Rime/wubi98_U.schema.yaml
   ```

3. 在鼠须管菜单里选“重新部署”。
4. 系统设置里输入源保留鼠须管即可，打英文用鼠须管的英文模式。

回滚：从备份里拷回这几个 yaml，删掉 `~/Library/Rime/lua/dvorak_remap.lua`，再重新部署。
第 2 步迁移挪走的文件不必挪回（挪回 `opencc/` 那几个会恢复崩溃）。

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

2. 编译（需要 Xcode 命令行工具；第 3 步的 check_dv.sh 也会先编译一次）：

   ```sh
   rime-test/tools/build.sh
   ```

3. 跑全部用例：

   ```sh
   rime-test/tools/check_dv.sh
   ```

check_dv.sh 先调用 build.sh 重新编译，所以改过 `tools/` 下的源码也不会测到旧程序；
再调用 make_users.sh，每次都从 `Rime/` 重新生成两个测试用户目录，
所以测的总是 `Rime/` 当前的配置：

- `user-dv`：`Rime/` 原样；
- `user-base`：`Rime/` 去掉 dvorak_remap 的挂载行，作为基线。

两者都不带用户词典。拼音反查用的 `py` 和三重注解用的 `wb_spelling` 由
`wubi98_ci.custom.yaml` 声明为方案依赖，部署时一并编译，不需要另外处理。
make_users.sh 还会核对 lua 里的映射表和 `dvorak_map.tsv` 与系统布局实测一致。

每个用例 `cases/<名字>.keys` 按 QWERTY 键名写：基线一侧直接喂入；
德沃夏克一侧带 `--dvorak`，先把每个物理键换成德沃夏克字符再喂入，
模拟系统布局为德沃夏克时鼠须管收到的字符。两侧逐键输出必须完全一致，
且日志里没有 E/F 级错误。另有两种可选的同名文件：

- `<名字>.dv.keys`：德沃夏克一侧改用它（物理键与 QWERTY 一侧不同，如拼音反查、
  符号输入里按德沃夏克字母敲）。比较前去掉每键标题行里的键名、keycode 和 mask，
  其余输出（含“处理=是/否”）仍须完全一致。
- `<名字>.expect`：其中每行（`#` 开头的和空行除外）必须作为整行出现在两侧的输出里，
  用来核对结果本身对不对（两侧一致但都错时也能发现）。

每个用例都在用户目录的临时克隆里运行，互不影响。结果和日志在 `rime-test/logs/`，
每个用例两侧各一对 `.out`/`.err`。

单独跑一个用例或几个键（先跑过一次 check_dv.sh 或 make_users.sh）：

```sh
rime-test/tools/run_case.sh rime-test/user-dv rime-test/cases/01_four_code.keys --dvorak
rime-test/tools/run_case.sh rime-test/user-dv /dev/null --dvorak a a a b
```

键写在命令行上时键文件给 `/dev/null`。run_case.sh 在临时克隆里运行，不改动
`user-dv`。直接调用 `rime-test/bin/rime_dvtest --user rime-test/user-dv` 则会把
会话写入（用户词典 `wubi98_ci.txt`、`user.yaml` 等）留在 `user-dv` 里，
之后单独运行的用例会从改动后的状态开始；check_dv.sh 每次重新生成用户目录，不受影响。

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
  - `wubi98_ci`、`wubi98_dz`、`wubi98_U` 三个 `.schema.yaml` 的 `key_binder` 删掉
    `{accept: KP_Decimal, send: period, when: composing}`：德沃夏克映射会把
    重发的 `period` 再转换成 `e`（见“做法”）。
  - `lua/switcher.lua` 修了三处：数字键超出候选数时取到 nil 报错；
    `key.ctrl()` 改为 `key:ctrl()`；设了 `menu/alternative_select_keys` 时
    选择下标差 1。
- `rime-test/shared/` 下的 `default.yaml`、`key_bindings.yaml`、`punctuation.yaml`、
  `symbols.yaml` 取自 [rime/rime-prelude](https://github.com/rime/rime-prelude)
  （提交 db691d2，即鼠须管 1.1.2 所带的版本，LGPL-3.0）。
- `rime-test/shared/opencc/` 是鼠须管 1.1.2 安装包里 `SharedSupport/opencc/`
  的原样副本，即 [OpenCC](https://github.com/BYVoid/OpenCC) 的转换配置和词典数据
  （Apache-2.0），供繁简转换用例使用。
- 本仓库新增的是德沃夏克映射（`Rime/lua/dvorak_remap.lua`、
  `Rime/wubi98_ci.custom.yaml` 里的挂载行、`Rime/squirrel.custom.yaml` 的
  `keyboard_layout`）和 `rime-test/` 测试环境。
- 原作者的码表、配置和 lua 版权归原作者所有，本仓库新增部分为德沃夏克映射和测试环境。
