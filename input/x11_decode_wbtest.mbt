// input 包解码层黑盒测试:合成 XEvent 字节缓冲 → InputEvent 的翻译规则。
// 偏移按 LP64:type@0、x_root@72、y_root@76、keycode/button@84。

///|
/// 合成 96 字节 XEvent:type@0、x_root@72、y_root@76、button/keycode@84。
fn xev(t : Int, code : Int, rx : Int, ry : Int) -> Bytes {
  Bytes::makei(96, fn(i) {
    let v = if i < 4 {
      t >> (i * 8)
    } else if i >= 72 && i < 76 {
      rx >> ((i - 72) * 8)
    } else if i >= 76 && i < 80 {
      ry >> ((i - 76) * 8)
    } else if i >= 84 && i < 88 {
      code >> ((i - 84) * 8)
    } else {
      0
    }
    (v & 0xFF).to_byte()
  })
}

///|
test "i32_le/u32_le: 小端解码与负数(x 坐标可为负)" {
  let b = Bytes::makei(8, fn(i) { (0xFF).to_byte() })
  assert_eq(u32_le(b, 0), 0xFFFFFFFF)
  assert_eq(i32_le(b, 0), -1)
  assert_eq(u32_le(xev(6, 0, -40, 50), 72).to_uint(), 4294967256U)
  assert_eq(i32_le(xev(6, 0, -40, 50), 72), -40)
}

///|
test "KeyPress → KeyDown(keysym 翻译);KeyRelease → KeyUp" {
  assert_true(
    match decode_x_event(xev(2, 25, 0, 0), 0x77UL) {
      Some(KeyDown(W)) => true
      _ => false
    },
  )
  assert_true(
    match decode_x_event(xev(3, 25, 0, 0), 0xFF1BUL) {
      Some(KeyUp(Esc)) => true
      _ => false
    },
  )
}

///|
test "ButtonPress: 左/中/右 → MouseDown,携带 root 坐标" {
  assert_true(
    match decode_x_event(xev(4, 1, 100, 50), 0UL) {
      Some(MouseDown(Left, x, y)) => x == 100.0 && y == 50.0
      _ => false
    },
  )
  assert_true(
    match decode_x_event(xev(4, 2, 0, 0), 0UL) {
      Some(MouseDown(Middle, _, _)) => true
      _ => false
    },
  )
  assert_true(
    match decode_x_event(xev(4, 3, 0, 0), 0UL) {
      Some(MouseDown(Right, _, _)) => true
      _ => false
    },
  )
}

///|
test "滚轮:Button4/5(纵)与 6/7(横)翻成 Wheel,Release 丢弃" {
  let dy = fn(ev : InputEvent?) -> Double {
    match ev {
      Some(Wheel(_, y)) => y
      _ => 999.0
    }
  }
  assert_eq(dy(decode_x_event(xev(4, 4, 0, 0), 0UL)), -1.0)
  assert_eq(dy(decode_x_event(xev(4, 5, 0, 0), 0UL)), 1.0)
  let dx = fn(ev : InputEvent?) -> Double {
    match ev {
      Some(Wheel(x, _)) => x
      _ => 999.0
    }
  }
  assert_eq(dx(decode_x_event(xev(4, 6, 0, 0), 0UL)), -1.0)
  assert_eq(dx(decode_x_event(xev(4, 7, 0, 0), 0UL)), 1.0)
  assert_true(decode_x_event(xev(5, 4, 0, 0), 0UL) is None)
}

///|
test "ButtonRelease → MouseUp;MotionNotify → MouseMove;未知类型 → None" {
  assert_true(
    match decode_x_event(xev(5, 3, 7, 8), 0UL) {
      Some(MouseUp(Right, x, y)) => x == 7.0 && y == 8.0
      _ => false
    },
  )
  assert_true(
    match decode_x_event(xev(6, 0, 12, 34), 0UL) {
      Some(MouseMove(x, y)) => x == 12.0 && y == 34.0
      _ => false
    },
  )
  // 33 = ClientMessage,输入泵不消费
  assert_true(decode_x_event(xev(33, 0, 0, 0), 0UL) is None)
}

///|
test "keysym_to_keycode: 字母/数字/功能键/未收录" {
  assert_true(keysym_to_keycode(0x77UL) is W)
  assert_true(keysym_to_keycode(0x41UL) is A)
  assert_true(keysym_to_keycode(0x31UL) is Num1)
  assert_true(keysym_to_keycode(0x0020UL) is Space)
  assert_true(keysym_to_keycode(0xFF1BUL) is Esc)
  assert_true(keysym_to_keycode(0xFF51UL) is Left)
  assert_true(keysym_to_keycode(0xFFE1UL) is Shift)
  assert_true(keysym_to_keycode(0xFFFFUL) is Delete)
  assert_true(keysym_to_keycode(0x1234UL) is Unknown(_))
  assert_true(keysym_to_keycode(0UL) is Unknown(_))
}

///|
test "label/index: 状态数组下标稳定,Unknown 不入数组" {
  assert_eq(W.index(), 22)
  assert_eq(Num9.index(), 35)
  assert_eq(Esc.index(), 37)
  assert_eq(Unknown(9).index(), -1)
  assert_eq(W.label(), "W")
  assert_eq(Num9.label(), "9")
  assert_eq(Esc.label(), "Esc")
}

///|
/// 合成 Xlib XIDeviceEvent 定长部分(192B):detail@56、root_x@88、root_y@96。
fn xiev(detail : Int, rx : Double, ry : Double) -> Bytes {
  let xb = rx.reinterpret_as_int64()
  let yb = ry.reinterpret_as_int64()
  Bytes::makei(256, fn(i) {
    let v = if i >= 56 && i < 60 {
      detail >> ((i - 56) * 8)
    } else if i >= 88 && i < 96 {
      ((xb >> ((i - 88) * 8)) & 0xFF).to_int()
    } else if i >= 96 && i < 104 {
      ((yb >> ((i - 96) * 8)) & 0xFF).to_int()
    } else {
      0
    }
    (v & 0xFF).to_byte()
  })
}

///|
test "decode_xi_event: XI_KeyPress/KeyRelease → KeyDown/Up(XKB keysym 前置)" {
  assert_true(
    match decode_xi_event(xiev(25, 0.0, 0.0), 2, 0x77UL) {
      Some(KeyDown(W)) => true
      _ => false
    },
  )
  assert_true(
    match decode_xi_event(xiev(25, 0.0, 0.0), 3, 0xFF1BUL) {
      Some(KeyUp(Esc)) => true
      _ => false
    },
  )
}

///|
test "decode_xi_event: ButtonPress 带 double 坐标;滚轮;Motion" {
  assert_true(
    match decode_xi_event(xiev(1, 100.5, 50.25), 4, 0UL) {
      Some(MouseDown(Left, x, y)) => x == 100.5 && y == 50.25
      _ => false
    },
  )
  assert_true(
    match decode_xi_event(xiev(4, 0.0, 0.0), 4, 0UL) {
      Some(Wheel(_, dy)) => dy == -100.0
      _ => false
    },
  )
  assert_true(
    match decode_xi_event(xiev(3, -7.5, 8.125), 6, 0UL) {
      Some(MouseMove(x, y)) => x == -7.5 && y == 8.125
      _ => false
    },
  )
}

///|
test "decode_xi_event: ButtonRelease 丢滚轮;未知 evtype → None" {
  assert_true(decode_xi_event(xiev(4, 0.0, 0.0), 5, 0UL) is None)
  assert_true(
    match decode_xi_event(xiev(3, 1.0, 2.0), 5, 0UL) {
      Some(MouseUp(Right, _, _)) => true
      _ => false
    },
  )
  assert_true(decode_xi_event(xiev(0, 0.0, 0.0), 11, 0UL) is None)
}
