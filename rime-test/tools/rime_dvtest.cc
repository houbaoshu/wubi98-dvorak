// rime_dvtest: 隔离的 librime 测试驱动。
//
// 用法:
//   rime_dvtest --shared DIR --user DIR [--schema ID] [--deploy-only]
//               [--dvorak [--dvorak-map TSV]] [-f KEYFILE] [KEY ...]
//
// KEY 的写法与 Rime 的键名一致，修饰键用 + 连接，例如:
//   a  2  comma  space  Return  Shift+Shift_L  Release+Shift_L  Control+grave
// 键名由 RimeGetKeycodeByName 解析，修饰键名由 RimeGetModifierByName 解析。
// KEYFILE 中按空白分隔，# 之后到行尾为注释。
// 两个以 @ 开头的指令不是按键：
//   @new_session  销毁当前会话再新建一个（模拟在另一个 App 里打字；
//                 不重启进程，选项靠 user.yaml 里保存的状态恢复）
//   @options      打印 zh_trad、single_char 两个开关的当前值
//
// --dvorak：用例仍按物理 QWERTY 键写，喂给 librime 前先换成同一物理键在
// 德沃夏克布局下的字符（模拟系统布局为德沃夏克时 Squirrel 收到的字符）。
// 映射表默认读 <可执行文件目录>/../tools/dvorak_map.tsv。为了能和 QWERTY
// 运行的 stdout 直接 diff，stdout 仍打印物理键名和 QWERTY keycode，
// 实际喂入的 keycode 打到 stderr。
//
// 部署由本程序调用 start_maintenance(True) 完成；日志 (glog) 只写到 stderr，
// 逐键结果写到 stdout。

#include <mach-o/dyld.h>
#include <rime_api.h>

#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

// 这两个函数在 librime 中导出（C++ 链接），但不在公开头文件里，
// 声明见 librime src/rime/key_table.h。
int RimeGetModifierByName(const char* name);
int RimeGetKeycodeByName(const char* name);

namespace {

const int kVoidSymbol = 0xffffff;  // XK_VoidSymbol
const int kDirective = -1;         // KeySpec 不是按键而是 @ 指令

struct KeySpec {
  std::string text;
  int keycode = 0;
  int mask = 0;
};

void Usage() {
  fprintf(stderr,
          "usage: rime_dvtest --shared DIR --user DIR [--schema ID] "
          "[--deploy-only] [--dvorak [--dvorak-map TSV]] [-f KEYFILE] "
          "[KEY ...]\n");
}

std::string DefaultDvorakMapPath() {
  char buf[PATH_MAX];
  uint32_t size = sizeof(buf);
  char resolved[PATH_MAX];
  if (_NSGetExecutablePath(buf, &size) != 0 || !realpath(buf, resolved))
    return "";
  std::string exe = resolved;
  return exe.substr(0, exe.rfind('/')) + "/../tools/dvorak_map.tsv";
}

// 读 gen_dvorak_map --tsv 的输出，建立 QWERTY 字符 -> 德沃夏克字符
// （同一物理键、同一 Shift 层）的映射。
bool LoadDvorakMap(const std::string& file, std::map<int, int>* qwerty_to_dv) {
  std::ifstream in(file);
  if (!in) {
    fprintf(stderr, "error: cannot open dvorak map: %s\n", file.c_str());
    return false;
  }
  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#')
      continue;
    std::istringstream cols(line);
    std::string vk, q, qs, d, ds;
    if (!(cols >> vk >> q >> qs >> d >> ds) || q.size() != 1 ||
        qs.size() != 1 || d.size() != 1 || ds.size() != 1) {
      fprintf(stderr, "error: bad line in dvorak map: %s\n", line.c_str());
      return false;
    }
    (*qwerty_to_dv)[(unsigned char)q[0]] = (unsigned char)d[0];
    (*qwerty_to_dv)[(unsigned char)qs[0]] = (unsigned char)ds[0];
  }
  return !qwerty_to_dv->empty();
}

std::string AbsolutePath(const std::string& p) {
  char buf[PATH_MAX];
  if (!realpath(p.c_str(), buf)) {
    fprintf(stderr, "error: cannot resolve path: %s\n", p.c_str());
    exit(2);
  }
  return buf;
}

// 解析 "Mod+Mod+keyname"。最后一段是键名，前面的每段都必须是修饰键名。
// 键名本身不会含 '+'（加号的键名是 plus）。
bool ParseKey(const std::string& text, KeySpec* out) {
  out->text = text;
  out->mask = 0;
  size_t start = 0;
  size_t plus;
  while ((plus = text.find('+', start)) != std::string::npos) {
    std::string mod = text.substr(start, plus - start);
    int m = RimeGetModifierByName(mod.c_str());
    if (m == 0) {
      fprintf(stderr, "error: unknown modifier '%s' in '%s'\n", mod.c_str(),
              text.c_str());
      return false;
    }
    out->mask |= m;
    start = plus + 1;
  }
  std::string name = text.substr(start);
  if (name.empty()) {
    fprintf(stderr, "error: empty key name in '%s'\n", text.c_str());
    return false;
  }
  out->keycode = RimeGetKeycodeByName(name.c_str());
  if (out->keycode == kVoidSymbol) {
    fprintf(stderr, "error: unknown key name '%s' in '%s'\n", name.c_str(),
            text.c_str());
    return false;
  }
  return true;
}

bool ReadKeyFile(const std::string& file, std::vector<std::string>* keys) {
  std::ifstream in(file);
  if (!in) {
    fprintf(stderr, "error: cannot open key file: %s\n", file.c_str());
    return false;
  }
  std::string line;
  while (std::getline(in, line)) {
    size_t hash = line.find('#');
    if (hash != std::string::npos)
      line.erase(hash);
    std::istringstream words(line);
    std::string w;
    while (words >> w)
      keys->push_back(w);
  }
  return true;
}

bool g_deploy_failed = false;

void OnNotification(void*, RimeSessionId, const char* type, const char* value) {
  fprintf(stderr, "[notification] %s: %s\n", type, value);
  if (!strcmp(type, "deploy") && !strcmp(value, "failure"))
    g_deploy_failed = true;
}

// 在 preedit 的光标处插入 ‸，便于看清光标位置。
std::string PreeditWithCursor(const RimeComposition& c) {
  if (!c.preedit)
    return "";
  std::string s = c.preedit;
  if (c.cursor_pos >= 0 && (size_t)c.cursor_pos <= s.size())
    s.insert(c.cursor_pos, "‸");
  return s;
}

void PrintState(RimeApi* rime, RimeSessionId session) {
  RIME_STRUCT(RimeCommit, commit);
  if (rime->get_commit(session, &commit)) {
    printf("    上屏: \"%s\"\n", commit.text ? commit.text : "");
    rime->free_commit(&commit);
  } else {
    printf("    上屏: (无)\n");
  }

  const char* input = rime->get_input(session);
  RIME_STRUCT(RimeContext, ctx);
  if (rime->get_context(session, &ctx)) {
    printf("    编码区: input=\"%s\" preedit=\"%s\"\n", input ? input : "",
           PreeditWithCursor(ctx.composition).c_str());
    if (ctx.menu.num_candidates > 0) {
      printf("    候选: 第%d页%s\n", ctx.menu.page_no + 1,
             ctx.menu.is_last_page ? "(末页)" : "");
      for (int i = 0; i < ctx.menu.num_candidates; ++i) {
        const RimeCandidate& cand = ctx.menu.candidates[i];
        const char* label =
            (ctx.select_labels && ctx.select_labels[i]) ? ctx.select_labels[i]
            : nullptr;
        char key[16];
        if (label)
          snprintf(key, sizeof(key), "%s", label);
        else if (ctx.menu.select_keys && i < (int)strlen(ctx.menu.select_keys))
          snprintf(key, sizeof(key), "%c", ctx.menu.select_keys[i]);
        else
          snprintf(key, sizeof(key), "%d", (i + 1) % 10);
        printf("      %s %s. %s%s%s%s\n",
               i == ctx.menu.highlighted_candidate_index ? "*" : " ", key,
               cand.text, cand.comment ? "  [" : "",
               cand.comment ? cand.comment : "", cand.comment ? "]" : "");
      }
    } else {
      printf("    候选: (无)\n");
    }
    rime->free_context(&ctx);
  }

  RIME_STRUCT(RimeStatus, status);
  if (rime->get_status(session, &status)) {
    printf("    状态: schema=%s ascii_mode=%d composing=%d full_shape=%d\n",
           status.schema_id ? status.schema_id : "?", status.is_ascii_mode,
           status.is_composing, status.is_full_shape);
    rime->free_status(&status);
  }
}

}  // namespace

int main(int argc, char* argv[]) {
  std::string shared_dir, user_dir, schema, key_file;
  bool deploy_only = false;
  bool dvorak = false;
  std::string dvorak_map_file;
  std::vector<std::string> key_texts;
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    auto next = [&](const char* opt) -> std::string {
      if (i + 1 >= argc) {
        fprintf(stderr, "error: %s needs an argument\n", opt);
        exit(2);
      }
      return argv[++i];
    };
    if (a == "--shared")
      shared_dir = next("--shared");
    else if (a == "--user")
      user_dir = next("--user");
    else if (a == "--schema")
      schema = next("--schema");
    else if (a == "-f")
      key_file = next("-f");
    else if (a == "--deploy-only")
      deploy_only = true;
    else if (a == "--dvorak")
      dvorak = true;
    else if (a == "--dvorak-map")
      dvorak_map_file = next("--dvorak-map");
    else if (a == "-h" || a == "--help") {
      Usage();
      return 0;
    } else
      key_texts.push_back(a);
  }
  if (shared_dir.empty() || user_dir.empty()) {
    Usage();
    return 2;
  }
  shared_dir = AbsolutePath(shared_dir);
  user_dir = AbsolutePath(user_dir);
  if (!key_file.empty() && !ReadKeyFile(key_file, &key_texts))
    return 2;
  std::map<int, int> qwerty_to_dv;
  if (dvorak) {
    if (dvorak_map_file.empty())
      dvorak_map_file = DefaultDvorakMapPath();
    if (!LoadDvorakMap(dvorak_map_file, &qwerty_to_dv))
      return 2;
    fprintf(stderr, "[dvtest] dvorak map: %s (%zu chars)\n",
            dvorak_map_file.c_str(), qwerty_to_dv.size());
  }

  std::vector<KeySpec> keys;
  for (const auto& t : key_texts) {
    KeySpec k;
    if (t[0] == '@') {
      if (t != "@new_session" && t != "@options") {
        fprintf(stderr, "error: unknown directive '%s'\n", t.c_str());
        return 2;
      }
      k.text = t;
      k.keycode = kDirective;
      keys.push_back(k);
      continue;
    }
    if (!ParseKey(t, &k))
      return 2;
    keys.push_back(k);
  }

  RimeApi* rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.shared_data_dir = shared_dir.c_str();
  traits.user_data_dir = user_dir.c_str();
  traits.distribution_name = "rime_dvtest";
  traits.distribution_code_name = "rime_dvtest";
  traits.distribution_version = "0.1";
  traits.app_name = "rime.dvtest";
  traits.min_log_level = 0;
  traits.log_dir = "";  // 只写 stderr

  rime->setup(&traits);
  rime->set_notification_handler(&OnNotification, nullptr);
  rime->initialize(nullptr);

  fprintf(stderr, "[dvtest] shared_data_dir=%s\n", shared_dir.c_str());
  fprintf(stderr, "[dvtest] user_data_dir=%s\n", user_dir.c_str());
  if (rime->start_maintenance(True)) {
    rime->join_maintenance_thread();
  }
  fprintf(stderr, "[dvtest] maintenance finished\n");
  if (g_deploy_failed) {
    fprintf(stderr, "error: deployment failed\n");
    rime->finalize();
    return 1;
  }

  if (deploy_only) {
    rime->finalize();
    return 0;
  }

  RimeSessionId session = rime->create_session();
  if (!session) {
    fprintf(stderr, "error: create_session failed\n");
    rime->finalize();
    return 1;
  }
  if (!schema.empty() && !rime->select_schema(session, schema.c_str())) {
    fprintf(stderr, "error: select_schema(%s) failed\n", schema.c_str());
    rime->destroy_session(session);
    rime->finalize();
    return 1;
  }

  printf("== 初始状态\n");
  PrintState(rime, session);
  for (size_t i = 0; i < keys.size(); ++i) {
    const KeySpec& k = keys[i];
    if (k.keycode == kDirective) {
      if (k.text == "@new_session") {
        rime->destroy_session(session);
        session = rime->create_session();
        if (!session) {
          fprintf(stderr, "error: create_session failed\n");
          rime->finalize();
          return 1;
        }
        printf("== [%zu] @new_session\n", i + 1);
        PrintState(rime, session);
      } else {
        printf("== [%zu] @options\n", i + 1);
        printf("    开关: zh_trad=%d single_char=%d\n",
               (int)rime->get_option(session, "zh_trad"),
               (int)rime->get_option(session, "single_char"));
      }
      continue;
    }
    int keycode = k.keycode;
    if (dvorak) {
      auto it = qwerty_to_dv.find(k.keycode);
      if (it != qwerty_to_dv.end())
        keycode = it->second;
      fprintf(stderr, "[dvtest] key %zu: %s 0x%x -> 0x%x\n", i + 1,
              k.text.c_str(), k.keycode, keycode);
    }
    Bool handled = rime->process_key(session, keycode, k.mask);
    printf("== [%zu] %s (keycode=0x%x mask=0x%x) 处理=%s\n", i + 1,
           k.text.c_str(), k.keycode, k.mask, handled ? "是" : "否");
    PrintState(rime, session);
  }
  fflush(stdout);

  rime->destroy_session(session);
  rime->finalize();
  return 0;
}
