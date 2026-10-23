// gen_dvorak_map: 用系统键盘布局实测生成 德沃夏克 <-> QWERTY 映射表。
//
// 对每个物理键（Mac 虚拟键码 0..50），分别用 com.apple.keylayout.US 和
// com.apple.keylayout.Dvorak 调 UCKeyTranslate，取无修饰和 Shift 两层的字符，
// 只保留两边都是可打印 ASCII（0x21..0x7e）的键。
//
// 用法:
//   gen_dvorak_map --tsv   输出 TSV（rime_dvtest --dvorak 读取）
//   gen_dvorak_map --lua   输出 dvorak_remap.lua 用的 Lua 表（只含不同的字符）

#include <Carbon/Carbon.h>
#include <stdio.h>
#include <string.h>

enum { kMaxVk = 50 };

static TISInputSourceRef FindLayout(const char* id) {
  CFStringRef cf_id =
      CFStringCreateWithCString(NULL, id, kCFStringEncodingUTF8);
  const void* keys[] = {kTISPropertyInputSourceID};
  const void* values[] = {cf_id};
  CFDictionaryRef filter =
      CFDictionaryCreate(NULL, keys, values, 1, &kCFTypeDictionaryKeyCallBacks,
                         &kCFTypeDictionaryValueCallBacks);
  CFArrayRef list = TISCreateInputSourceList(filter, true);
  CFRelease(filter);
  CFRelease(cf_id);
  if (!list || CFArrayGetCount(list) == 0) {
    fprintf(stderr, "error: keyboard layout not found: %s\n", id);
    return NULL;
  }
  TISInputSourceRef src = (TISInputSourceRef)CFRetain(
      CFArrayGetValueAtIndex(list, 0));
  CFRelease(list);
  return src;
}

// 返回该键在给定修饰状态下产生的单个字符；不是单个字符时返回 0。
static UniChar Translate(TISInputSourceRef src, UInt16 vk, UInt32 modifiers) {
  CFDataRef data = (CFDataRef)TISGetInputSourceProperty(
      src, kTISPropertyUnicodeKeyLayoutData);
  if (!data)
    return 0;
  const UCKeyboardLayout* layout =
      (const UCKeyboardLayout*)CFDataGetBytePtr(data);
  UInt32 dead = 0;
  UniChar chars[4];
  UniCharCount len = 0;
  OSStatus err = UCKeyTranslate(layout, vk, kUCKeyActionDown,
                                (modifiers >> 8) & 0xff, LMGetKbdType(),
                                kUCKeyTranslateNoDeadKeysMask, &dead, 4, &len,
                                chars);
  if (err != noErr || len != 1)
    return 0;
  return chars[0];
}

static int Printable(UniChar c) { return c >= 0x21 && c <= 0x7e; }

int main(int argc, char* argv[]) {
  int lua = argc > 1 && !strcmp(argv[1], "--lua");
  int tsv = argc > 1 && !strcmp(argv[1], "--tsv");
  if (!lua && !tsv) {
    fprintf(stderr, "usage: gen_dvorak_map --tsv | --lua\n");
    return 2;
  }
  TISInputSourceRef us = FindLayout("com.apple.keylayout.US");
  TISInputSourceRef dv = FindLayout("com.apple.keylayout.Dvorak");
  if (!us || !dv)
    return 1;

  // 德沃夏克字符 -> QWERTY 字符，用来检查同一个德沃夏克字符不会出现在两个键上。
  UniChar seen[128] = {0};
  if (tsv)
    printf("# vk\tqwerty\tqwerty_shift\tdvorak\tdvorak_shift\n");
  else
    printf("local DVORAK_TO_QWERTY = {\n");
  for (UInt16 vk = 0; vk <= kMaxVk; ++vk) {
    UniChar q[2] = {Translate(us, vk, 0), Translate(us, vk, shiftKey)};
    UniChar d[2] = {Translate(dv, vk, 0), Translate(dv, vk, shiftKey)};
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
  CFRelease(us);
  CFRelease(dv);
  return 0;
}
