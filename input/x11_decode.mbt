// X11 事件字节解码(纯函数,无 FFI):把 XNextEvent 填好的 XEvent 缓冲
// 翻译成 InputEvent。独立成纯层是为了黑盒单测能覆盖字段偏移与翻译规则,
// 真机 FFI 只剩 XNextEvent/XLookupKeysym 两个调用点。
//
// 偏移按 LP64(x86-64 Linux / x64 Windows)XEvent 布局:
//   type@0(i32)  window@32(u64)  x@64  y@68  x_root@72  y_root@76
//   state@80(i32)  keycode/button@84(i32,XKeyEvent 与 XButtonEvent 同位)
// 小端;keycode/button 等宽同位正是 XKey/Button 事件共布局的设计。

///|
/// XIDeviceEvent(Xlib 版)字段偏移(LP64,与 native_x11.c 对齐)。
const SF_OFF_DEV_DETAIL : Int = 56

///|
const SF_OFF_DEV_ROOTX : Int = 88

///|
const SF_OFF_DEV_ROOTY : Int = 96

///|
/// X 事件类型:XKeyPress(XI2 事件类型值与 core 相同,XI2.h:193-196)
pub const X_KEY_PRESS : Int = 2

///|
/// X 事件类型:XKeyRelease
pub const X_KEY_RELEASE : Int = 3

///|
/// X 事件类型:XButtonPress
pub const X_BUTTON_PRESS : Int = 4

///|
/// X 事件类型:XButtonRelease
pub const X_BUTTON_RELEASE : Int = 5

///|
/// X 事件类型:XMotionNotify
pub const X_MOTION_NOTIFY : Int = 6

///|
/// 小端读有符号 i32(x/y 可为负;Int 32 位,最高字节左移自然补符号)。
pub fn i32_le(buf : Bytes, off : Int) -> Int {
  buf[off].to_int() |
  (buf[off + 1].to_int() << 8) |
  ((buf[off + 2].to_int() << 16) | (buf[off + 3].to_int() << 24))
}

///|
/// 小端读无符号 u32(button/keycode/state 恒非负)。
pub fn u32_le(buf : Bytes, off : Int) -> Int {
  buf[off].to_int() |
  (buf[off + 1].to_int() << 8) |
  ((buf[off + 2].to_int() << 16) | (buf[off + 3].to_int() << 24))
}

///|
/// 小端读 u64(cookie.data 指针;Int64 按位,本码只当不透明指针用)。
pub fn u64_le(buf : Bytes, off : Int) -> UInt64 {
  (u32_le(buf, off + 4).to_uint64() << 32) | u32_le(buf, off).to_uint64()
}

///|
/// 解码一个 X 事件。keysym 为键盘事件预取的 XLookupKeysym 结果
/// (非键盘事件传 0);XKB 键位表随机器不同,硬件 keycode 不作直接翻译。
/// 未知类型(ClientMessage 等)返回 None;滚轮 Button4/5(纵)与 6/7(横)
/// 翻译为 Wheel,且其 Release 丢弃(一对按压只出一次事件)。
pub fn decode_x_event(buf : Bytes, keysym : UInt64) -> InputEvent? {
  let t = i32_le(buf, 0)
  let rx = Int::to_double(i32_le(buf, 72))
  let ry = Int::to_double(i32_le(buf, 76))
  let code = u32_le(buf, 84)
  if t == X_KEY_PRESS {
    Some(KeyDown(keysym_to_keycode(keysym)))
  } else if t == X_KEY_RELEASE {
    Some(KeyUp(keysym_to_keycode(keysym)))
  } else if t == X_BUTTON_PRESS {
    // 纵滚轮:Button4 上(dy<0 拉近)、Button5 下(dy>0 拉远);
    // 横滚轮:Button6 左、Button7 右
    if code == 4 {
      Some(Wheel(0.0, -1.0))
    } else if code == 5 {
      Some(Wheel(0.0, 1.0))
    } else if code == 6 {
      Some(Wheel(-1.0, 0.0))
    } else if code == 7 {
      Some(Wheel(1.0, 0.0))
    } else {
      Some(MouseDown(x_button(code), rx, ry))
    }
  } else if t == X_BUTTON_RELEASE {
    // 滚轮释放丢弃
    if code >= 4 && code <= 7 {
      None
    } else {
      Some(MouseUp(x_button(code), rx, ry))
    }
  } else if t == X_MOTION_NOTIFY {
    Some(MouseMove(rx, ry))
  } else {
    None
  }
}

///|
/// X button 码 → 抽象鼠标键(1/2/3 = 左/中/右;4-7 滚轮已在调用方消费;
/// 其余侧键归 Other(原码))。
fn x_button(code : Int) -> MouseButton {
  if code == 1 {
    Left
  } else if code == 2 {
    Middle
  } else if code == 3 {
    Right
  } else {
    Other(code)
  }
}

///|
/// XNoSymbol
const X_NO_SYMBOL : UInt64 = 0UL

///|
/// keysym → 抽象键码。字母取小写 keysym(0x61..0x7A,keysym 第 0 列不分
/// Shift;大写区 0x41..0x5A 兜底同映射)、数字 0x30..0x39、功能键 0xFFxx;
/// 未收录归 Unknown(低 32 位)。
pub fn keysym_to_keycode(ks : UInt64) -> KeyCode {
  if ks == X_NO_SYMBOL {
    return Unknown(-1)
  }
  if ks >= 0x61UL && ks <= 0x7AUL {
    // 'a'..'z' → A..Z
    return letter(ks.to_int() - 0x61)
  }
  if ks >= 0x41UL && ks <= 0x5AUL {
    // 'A'..'Z' 兜底(keysym 列 0 理论不会出,组合层残留时接住)
    return letter(ks.to_int() - 0x41)
  }
  if ks >= 0x30UL && ks <= 0x39UL {
    // '0'..'9'
    return digit(ks.to_int() - 0x30)
  }
  match ks {
    0x0020UL => Space
    0xFF1BUL => Esc
    0xFF0DUL => Enter
    0xFF09UL => Tab
    0xFF08UL => Backspace
    0xFF51UL => Left
    0xFF52UL => Up
    0xFF53UL => Right
    0xFF54UL => Down
    0xFFE1UL => Shift
    0xFFE2UL => Shift
    0xFFE3UL => Ctrl
    0xFFE4UL => Ctrl
    0xFFE7UL => Alt
    0xFFE8UL => Alt
    0xFFE9UL => Alt
    0xFFEAUL => Alt
    0xFFFFUL => Delete
    _ => Unknown(ks.to_int())
  }
}

///|
fn letter(i : Int) -> KeyCode {
  match i {
    0 => A
    1 => B
    2 => C
    3 => D
    4 => E
    5 => F
    6 => G
    7 => H
    8 => I
    9 => J
    10 => K
    11 => L
    12 => M
    13 => N
    14 => O
    15 => P
    16 => Q
    17 => R
    18 => S
    19 => T
    20 => U
    21 => V
    22 => W
    23 => X
    24 => Y
    _ => Z
  }
}

///|
fn digit(i : Int) -> KeyCode {
  match i {
    0 => Num0
    1 => Num1
    2 => Num2
    3 => Num3
    4 => Num4
    5 => Num5
    6 => Num6
    7 => Num7
    8 => Num8
    _ => Num9
  }
}

///|
/// 解码一个 XInput2 设备事件(xi_buf = 泵线程拷出的 XIDeviceEvent 定长
/// 部分;evtype 来自 cookie 头)。偏移按 LP64 Xlib XIDeviceEvent:
///   detail@56(keycode/button)  root_x@88  root_y@96(C double)
/// 字段提取后委托 decode_record(翻译规则单一出处)。
pub fn decode_xi_event(
  buf : Bytes,
  evtype : Int,
  keysym : UInt64,
) -> InputEvent? {
  decode_record(
    evtype,
    i32_le(buf, SF_OFF_DEV_DETAIL),
    keysym,
    sf_x11_bits_to_f64(f64_bits(buf, SF_OFF_DEV_ROOTX)),
    sf_x11_bits_to_f64(f64_bits(buf, SF_OFF_DEV_ROOTY)),
  )
}

///|
/// 小端读 C double 的位型(配合 sf_x11_bits_to_f64 按位重解释;
/// 两段 u32 各自零扩展后拼 64 位)。
fn f64_bits(buf : Bytes, off : Int) -> Int64 {
  let lo = u32_le(buf, off).to_int64() & 0xFFFFFFFFL
  let hi = u32_le(buf, off + 4).to_int64() & 0xFFFFFFFFL
  (hi << 32) | lo
}

///|
/// 泵记录 → InputEvent(纯函数;字段由泵线程从 X 事件打包:
/// evtype=2..6(XI2 与 core 同值)、detail=keycode/button、keysym 已由
/// XLookupKeysym/XkbKeycodeToKeysym 解出、rx/ry=root 坐标)。
pub fn decode_record(
  evtype : Int,
  detail : Int,
  keysym : UInt64,
  rx : Double,
  ry : Double,
) -> InputEvent? {
  if evtype == X_KEY_PRESS {
    Some(KeyDown(keysym_to_keycode(keysym)))
  } else if evtype == X_KEY_RELEASE {
    Some(KeyUp(keysym_to_keycode(keysym)))
  } else if evtype == X_BUTTON_PRESS {
    // 纵滚轮 Button4/5,横滚轮 6/7;幅度按 DOM deltaY 约定 ±100/格,
    // 可直接喂 OrbitControls::zoom(three.js 同式 0.95^(zoomSpeed·|Δ|·0.01))
    if detail == 4 {
      Some(Wheel(0.0, -100.0))
    } else if detail == 5 {
      Some(Wheel(0.0, 100.0))
    } else if detail == 6 {
      Some(Wheel(-100.0, 0.0))
    } else if detail == 7 {
      Some(Wheel(100.0, 0.0))
    } else {
      Some(MouseDown(x_button(detail), rx, ry))
    }
  } else if evtype == X_BUTTON_RELEASE {
    if detail >= 4 && detail <= 7 {
      None // 滚轮释放丢弃
    } else {
      Some(MouseUp(x_button(detail), rx, ry))
    }
  } else if evtype == X_MOTION_NOTIFY {
    Some(MouseMove(rx, ry))
  } else {
    None
  }
}
