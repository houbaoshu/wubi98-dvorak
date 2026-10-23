-- dvorak_remap.lua
-- 把德沃夏克布局产生的字符按物理键位置换回 QWERTY 字符，再交给引擎重新处理，
-- 使中文模式下按物理 QWERTY 位置打五笔；英文模式由前面的 ascii_composer 先处理，
-- 保持德沃夏克。
--
-- 挂载（wubi98_ci.custom.yaml）：
--   "engine/processors/@after 0": "lua_processor@*dvorak_remap"
-- 测试见 rime-test/tools/check_dv.sh（由 make_users.sh 从 Rime/ 生成测试目录）。
--
-- 只转换无修饰键和只带 Shift 的键；带 Ctrl/Alt/Super/Lock 等其他修饰、
-- 以及按键松开事件，原样放行。
--
-- 拼音反查（z 前缀，affix_segmentor@rvlk1）里按德沃夏克字母拼拼音：
-- 字母原样放行；; ' , . 及其 Shift 层（换算结果是 QWERTY 字母）也原样放行，
-- 分别是选第二、第三候选和标点；其余符号照旧按物理位置转换（翻页等）。
-- 进入反查的 z 本身是在编码区为空时按物理 Z 键转换出来的，不受影响。

local kRejected = 0
local kAccepted = 1
local kNoop = 2

local kShiftMask = 0x1

-- 以下映射表由 rime-test/tools/gen_dvorak_map --lua 生成（系统布局
-- com.apple.keylayout.Dvorak 与 com.apple.keylayout.US 实测），请勿手改。
-- 键：德沃夏克字符的 keycode；值：同一物理键、同一 Shift 层的 QWERTY 字符。
-- BEGIN GENERATED
local DVORAK_TO_QWERTY = {
  [0x6f] = 0x73,  -- o -> s (vk 0x01)
  [0x4f] = 0x53,  -- O -> S (vk 0x01, shift)
  [0x65] = 0x64,  -- e -> d (vk 0x02)
  [0x45] = 0x44,  -- E -> D (vk 0x02, shift)
  [0x75] = 0x66,  -- u -> f (vk 0x03)
  [0x55] = 0x46,  -- U -> F (vk 0x03, shift)
  [0x64] = 0x68,  -- d -> h (vk 0x04)
  [0x44] = 0x48,  -- D -> H (vk 0x04, shift)
  [0x69] = 0x67,  -- i -> g (vk 0x05)
  [0x49] = 0x47,  -- I -> G (vk 0x05, shift)
  [0x3b] = 0x7a,  -- ; -> z (vk 0x06)
  [0x3a] = 0x5a,  -- : -> Z (vk 0x06, shift)
  [0x71] = 0x78,  -- q -> x (vk 0x07)
  [0x51] = 0x58,  -- Q -> X (vk 0x07, shift)
  [0x6a] = 0x63,  -- j -> c (vk 0x08)
  [0x4a] = 0x43,  -- J -> C (vk 0x08, shift)
  [0x6b] = 0x76,  -- k -> v (vk 0x09)
  [0x4b] = 0x56,  -- K -> V (vk 0x09, shift)
  [0x78] = 0x62,  -- x -> b (vk 0x0b)
  [0x58] = 0x42,  -- X -> B (vk 0x0b, shift)
  [0x27] = 0x71,  -- ' -> q (vk 0x0c)
  [0x22] = 0x51,  -- " -> Q (vk 0x0c, shift)
  [0x2c] = 0x77,  -- , -> w (vk 0x0d)
  [0x3c] = 0x57,  -- < -> W (vk 0x0d, shift)
  [0x2e] = 0x65,  -- . -> e (vk 0x0e)
  [0x3e] = 0x45,  -- > -> E (vk 0x0e, shift)
  [0x70] = 0x72,  -- p -> r (vk 0x0f)
  [0x50] = 0x52,  -- P -> R (vk 0x0f, shift)
  [0x66] = 0x79,  -- f -> y (vk 0x10)
  [0x46] = 0x59,  -- F -> Y (vk 0x10, shift)
  [0x79] = 0x74,  -- y -> t (vk 0x11)
  [0x59] = 0x54,  -- Y -> T (vk 0x11, shift)
  [0x5d] = 0x3d,  -- ] -> = (vk 0x18)
  [0x7d] = 0x2b,  -- } -> + (vk 0x18, shift)
  [0x5b] = 0x2d,  -- [ -> - (vk 0x1b)
  [0x7b] = 0x5f,  -- { -> _ (vk 0x1b, shift)
  [0x3d] = 0x5d,  -- = -> ] (vk 0x1e)
  [0x2b] = 0x7d,  -- + -> } (vk 0x1e, shift)
  [0x72] = 0x6f,  -- r -> o (vk 0x1f)
  [0x52] = 0x4f,  -- R -> O (vk 0x1f, shift)
  [0x67] = 0x75,  -- g -> u (vk 0x20)
  [0x47] = 0x55,  -- G -> U (vk 0x20, shift)
  [0x2f] = 0x5b,  -- / -> [ (vk 0x21)
  [0x3f] = 0x7b,  -- ? -> { (vk 0x21, shift)
  [0x63] = 0x69,  -- c -> i (vk 0x22)
  [0x43] = 0x49,  -- C -> I (vk 0x22, shift)
  [0x6c] = 0x70,  -- l -> p (vk 0x23)
  [0x4c] = 0x50,  -- L -> P (vk 0x23, shift)
  [0x6e] = 0x6c,  -- n -> l (vk 0x25)
  [0x4e] = 0x4c,  -- N -> L (vk 0x25, shift)
  [0x68] = 0x6a,  -- h -> j (vk 0x26)
  [0x48] = 0x4a,  -- H -> J (vk 0x26, shift)
  [0x2d] = 0x27,  -- - -> ' (vk 0x27)
  [0x5f] = 0x22,  -- _ -> " (vk 0x27, shift)
  [0x74] = 0x6b,  -- t -> k (vk 0x28)
  [0x54] = 0x4b,  -- T -> K (vk 0x28, shift)
  [0x73] = 0x3b,  -- s -> ; (vk 0x29)
  [0x53] = 0x3a,  -- S -> : (vk 0x29, shift)
  [0x77] = 0x2c,  -- w -> , (vk 0x2b)
  [0x57] = 0x3c,  -- W -> < (vk 0x2b, shift)
  [0x7a] = 0x2f,  -- z -> / (vk 0x2c)
  [0x5a] = 0x3f,  -- Z -> ? (vk 0x2c, shift)
  [0x62] = 0x6e,  -- b -> n (vk 0x2d)
  [0x42] = 0x4e,  -- B -> N (vk 0x2d, shift)
  [0x76] = 0x2e,  -- v -> . (vk 0x2f)
  [0x56] = 0x3e,  -- V -> > (vk 0x2f, shift)
}
-- END GENERATED

local function is_letter(keycode)
  return (keycode >= 0x41 and keycode <= 0x5a) or
         (keycode >= 0x61 and keycode <= 0x7a)
end

-- 编码区最后一段是拼音反查段：刚按 z 时带 rvlk1_prefix，拼音字母段带 rvlk1。
local function in_reverse_lookup(context)
  local composition = context.composition
  if composition:empty() then
    return false
  end
  local seg = composition:back()
  return seg:has_tag("rvlk1") or seg:has_tag("rvlk1_prefix")
end

local function init(env)
  env.redispatching = false
end

local function func(key, env)
  -- 重发出去的那一层：直接放行，交给后面的处理器。
  if env.redispatching then
    return kNoop
  end
  if key:release() or (key.modifier & ~kShiftMask) ~= 0 then
    return kNoop
  end
  local qwerty = DVORAK_TO_QWERTY[key.keycode]
  if not qwerty then
    return kNoop
  end
  if (is_letter(key.keycode) or is_letter(qwerty)) and
     in_reverse_lookup(env.engine.context) then
    return kNoop
  end
  env.redispatching = true
  local ok, handled = pcall(env.engine.process_key, env.engine,
                            KeyEvent(qwerty, key.modifier))
  env.redispatching = false
  if not ok then
    error(handled)
  end
  -- 外层按内层的处理结果返回：内层未处理时拒绝，交给应用。
  return handled and kAccepted or kRejected
end

return { init = init, func = func }
