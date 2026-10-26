// gen_dvorak_map_xkb: gen_dvorak_map 的 Linux 版，用 xkbcommon 实测 XKB 布局
// us 与 us(dvorak) 生成 德沃夏克 <-> QWERTY 映射表。
//
// 按 Mac 虚拟键码 0..50 的顺序遍历同样的物理键（换成对应的 evdev 键码），
// 取无修饰和 Shift 两层的字符，只保留两边都是可打印 ASCII（0x21..0x7e）的键。
// 输出格式与 gen_dvorak_map.c 逐字节相同（第一列和 Lua 注释里仍是 Mac 虚拟
// 键码），所以 make_users.sh 可以直接拿它核对 dvorak_remap.lua 和
// dvorak_map.tsv，也就核对了 XKB 的德沃夏克与苹果的德沃夏克逐键一致。
//
// 用法:
//   gen_dvorak_map --tsv   输出 TSV（rime_dvtest --dvorak 读取）
//   gen_dvorak_map --lua   输出 dvorak_remap.lua 用的 Lua 表（只含不同的字符）

#include <linux/input-event-codes.h>
#include <stdio.h>
#include <string.h>
#include <xkbcommon/xkbcommon.h>

enum { kMaxVk = 50 };

// Mac 虚拟键码（kVK_ANSI_* 等）-> 同一物理键的 evdev 键码；0 表示跳过。
// 0x0a 是 ISO 键盘 Z 左边的键：苹果 US 布局出 §（不是 ASCII，Mac 版跳过），
// XKB 出 < >，这里也跳过，两边输出才一致。
static const int kVkToEvdev[kMaxVk + 1] = {
    [0x00] = KEY_A,          [0x01] = KEY_S,         [0x02] = KEY_D,
    [0x03] = KEY_F,          [0x04] = KEY_H,         [0x05] = KEY_G,
    [0x06] = KEY_Z,          [0x07] = KEY_X,         [0x08] = KEY_C,
    [0x09] = KEY_V,          [0x0a] = 0,             [0x0b] = KEY_B,
    [0x0c] = KEY_Q,          [0x0d] = KEY_W,         [0x0e] = KEY_E,
    [0x0f] = KEY_R,          [0x10] = KEY_Y,         [0x11] = KEY_T,
    [0x12] = KEY_1,          [0x13] = KEY_2,         [0x14] = KEY_3,
    [0x15] = KEY_4,          [0x16] = KEY_6,         [0x17] = KEY_5,
    [0x18] = KEY_EQUAL,      [0x19] = KEY_9,         [0x1a] = KEY_7,
    [0x1b] = KEY_MINUS,      [0x1c] = KEY_8,         [0x1d] = KEY_0,
    [0x1e] = KEY_RIGHTBRACE, [0x1f] = KEY_O,         [0x20] = KEY_U,
    [0x21] = KEY_LEFTBRACE,  [0x22] = KEY_I,         [0x23] = KEY_P,
    [0x24] = KEY_ENTER,      [0x25] = KEY_L,         [0x26] = KEY_J,
    [0x27] = KEY_APOSTROPHE, [0x28] = KEY_K,         [0x29] = KEY_SEMICOLON,
    [0x2a] = KEY_BACKSLASH,  [0x2b] = KEY_COMMA,     [0x2c] = KEY_SLASH,
    [0x2d] = KEY_N,          [0x2e] = KEY_M,         [0x2f] = KEY_DOT,
    [0x30] = KEY_TAB,        [0x31] = KEY_SPACE,     [0x32] = KEY_GRAVE,
};

struct Layout {
  struct xkb_keymap* keymap;
  struct xkb_state* plain;
  struct xkb_state* shift;
};

static int LoadLayout(struct xkb_context* ctx, const char* variant,
                      struct Layout* out) {
  struct xkb_rule_names names = {
      .rules = "evdev", .model = "pc105", .layout = "us", .variant = variant};
  out->keymap = xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
  if (!out->keymap) {
    fprintf(stderr, "error: keyboard layout not found: us(%s)\n", variant);
    return 0;
  }
  out->plain = xkb_state_new(out->keymap);
  out->shift = xkb_state_new(out->keymap);
  xkb_mod_index_t shift = xkb_keymap_mod_get_index(out->keymap, XKB_MOD_NAME_SHIFT);
  xkb_state_update_mask(out->shift, 1u << shift, 0, 0, 0, 0, 0);
  return 1;
}

// 返回该键产生的单个字符；不是单个字符时返回 0。
static unsigned Translate(struct xkb_state* state, int evdev) {
  return xkb_state_key_get_utf32(state, evdev + 8);
}

static int Printable(unsigned c) { return c >= 0x21 && c <= 0x7e; }

int main(int argc, char* argv[]) {
  int lua = argc > 1 && !strcmp(argv[1], "--lua");
  int tsv = argc > 1 && !strcmp(argv[1], "--tsv");
  if (!lua && !tsv) {
    fprintf(stderr, "usage: gen_dvorak_map --tsv | --lua\n");
    return 2;
  }
  struct xkb_context* ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  struct Layout us, dv;
  if (!ctx || !LoadLayout(ctx, "", &us) || !LoadLayout(ctx, "dvorak", &dv))
    return 1;

  // 德沃夏克字符 -> QWERTY 字符，用来检查同一个德沃夏克字符不会出现在两个键上。
  unsigned seen[128] = {0};
  if (tsv)
    printf("# vk\tqwerty\tqwerty_shift\tdvorak\tdvorak_shift\n");
  else
    printf("local DVORAK_TO_QWERTY = {\n");
  for (int vk = 0; vk <= kMaxVk; ++vk) {
    int evdev = kVkToEvdev[vk];
    if (!evdev)
      continue;
    unsigned q[2] = {Translate(us.plain, evdev), Translate(us.shift, evdev)};
    unsigned d[2] = {Translate(dv.plain, evdev), Translate(dv.shift, evdev)};
    if (!Printable(q[0]) || !Printable(q[1]) || !Printable(d[0]) ||
        !Printable(d[1]))
      continue;
    if (tsv)
      printf("0x%02x\t%c\t%c\t%c\t%c\n", vk, q[0], q[1], d[0], d[1]);
    for (int layer = 0; layer < 2; ++layer) {
      if (seen[d[layer]] && seen[d[layer]] != q[layer]) {
        fprintf(stderr, "error: dvorak char 0x%02x maps to both 0x%02x and "
                "0x%02x\n", d[layer], seen[d[layer]], q[layer]);
        return 1;
      }
      seen[d[layer]] = q[layer];
      if (lua && d[layer] != q[layer])
        printf("  [0x%02x] = 0x%02x,  -- %c -> %c (vk 0x%02x%s)\n", d[layer],
               q[layer], d[layer], q[layer], vk, layer ? ", shift" : "");
    }
  }
  if (lua)
    printf("}\n");
  return 0;
}
