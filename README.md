# 98 五笔 + 德沃夏克（鼠须管 / Rime）

[![安装测试](https://github.com/houbaoshu/wubi98-dvorak/actions/workflows/install-test.yml/badge.svg)](https://github.com/houbaoshu/wubi98-dvorak/actions/workflows/install-test.yml)

98 五笔 + Dvorak 的 Rime 配置，支持 Mac（鼠须管）和 Linux（ibus-rime）。

## 安装

### Mac

```sh
curl -fsSL https://raw.githubusercontent.com/houbaoshu/wubi98-dvorak/main/install.sh | bash
```

装完在 系统设置 → 键盘 → 文字输入 → 输入法“编辑…” 里，简体中文下添加“鼠须管”；键盘布局保持“Dvorak”。

### Linux（Debian 13）

```sh
sudo apt install --no-install-recommends ibus-rime librime-plugin-lua librime-bin libopencc-data rsync fonts-noto-cjk git curl
curl -fsSL https://raw.githubusercontent.com/houbaoshu/wubi98-dvorak/main/install.sh | bash
```

装完在 设置 → 键盘 → 输入源 里加“中文（Rime）”（放在“英语（Dvorak）”后面），注销重新登录一次。

再次运行同一行 curl 命令就是更新。

## 使用

- 右 Shift：切中英文
- ``Ctrl+` ``：方案菜单（单字 / 超集 / 繁简）
- `z`：拼音反查
- `/`：符号输入
- `date` 日期、`time` 时间、`day` 星期、`luna` 农历、`term` 节气

## 字体

98WB 字体来自 98 五笔小组（yanhuacuo），原仓库 https://github.com/yanhuacuo/98wubi-unicode ，版权归原作者所有。本仓库不含字体文件，安装时从原仓库下载。
