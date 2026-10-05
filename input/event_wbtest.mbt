// input 包状态聚合黑盒测试:事件流喂入 → is_down/move_axis/指针状态。

///|
test "InputState: KeyDown/KeyUp 改变 is_down,Unknown 不入状态" {
  let st = InputState::new()
  assert_true(!st.is_down(W))
  st.apply(KeyDown(W))
  assert_true(st.is_down(W))
  st.apply(KeyDown(Unknown(9999)))
  assert_true(!st.is_down(Unknown(9999)))
  st.apply(KeyUp(W))
  assert_true(!st.is_down(W))
}

///|
test "InputState: move_axis 汇 WASD(D-A, S-W)" {
  let st = InputState::new()
  let (dx, dz) = st.move_axis()
  assert_true(dx == 0.0 && dz == 0.0)
  st.apply(KeyDown(W))
  st.apply(KeyDown(D))
  let (dx2, dz2) = st.move_axis()
  assert_true(dx2 == 1.0 && dz2 == -1.0)
  st.apply(KeyDown(A))
  st.apply(KeyDown(S))
  let (dx3, dz3) = st.move_axis()
  assert_true(dx3 == 0.0 && dz3 == 0.0)
}

///|
test "InputState: 鼠标键状态与指针坐标" {
  let st = InputState::new()
  st.apply(MouseDown(Left, 0.0, 0.0))
  assert_true(st.is_button_down(Left))
  assert_true(!st.is_button_down(Right))
  st.apply(MouseMove(12.0, 34.0))
  let (x, y) = st.mouse_pos()
  assert_true(x == 12.0 && y == 34.0)
  st.apply(MouseUp(Left, 0.0, 0.0))
  assert_true(!st.is_button_down(Left))
  // Other 侧键不入状态(接口不炸)
  st.apply(MouseDown(Other(8), 0.0, 0.0))
  assert_true(!st.is_button_down(Other(8)))
  // 滚轮不改状态
  st.apply(Wheel(0.0, 1.0))
  let (x2, y2) = st.mouse_pos()
  assert_true(x2 == 12.0 && y2 == 34.0)
}

///|
test "InputState: pressed_keys 按下标序列出(日志用)" {
  let st = InputState::new()
  st.apply(KeyDown(W))
  st.apply(KeyDown(Num9))
  st.apply(KeyDown(Esc))
  let names = st.pressed_keys()
  // Num9(35) < Esc(37) < W(22)? W=22 最小在前:W, 9, Esc
  assert_eq(names.join(","), "W,9,Esc")
}

///|
test "InputSystem: open_x11 真连接(根窗口),poll 空队列,close 幂等;无 X 环境跳过" {
  // 先借一条临时连接取真实根窗口 XID(XID 是服务器全局资源,跨连接有效);
  // 无 libX11/无 DISPLAY 的构建环境 open 返回 0,视为跳过
  let probe = sf_x11_open_display()
  if probe == 0UL {
    return
  }
  let root = sf_x11_default_root_window(probe)
  println("DBG probe=\{probe} root=\{root}")
  assert_true(root != 0UL)
  sf_x11_close_display(probe)
  let sys = InputSystem::open_x11([root]) catch {
    e => {
      println("DBG open err: \{e}")
      assert_true(false)
      return
    }
  }
  assert_true(sys.poll().length() == 0)
  sys.close()
  sys.close()
  assert_true(sys.poll().length() == 0)
}

///|
test "InputSystem: 无效 XID 不炸进程(错误处理器吞本连接 BadWindow)" {
  let sys = InputSystem::open_x11([0xDEAD0000UL, 0xDEAD0001UL]) catch {
    // 无 X 环境跳过
    _ => return
  }
  // XSelectInput 到不存在窗口会异步回 BadWindow;Xlib 默认处理器会
  // 打印并 exit(1),垫片装的处理器只吞本连接错误,这里活下来即通过
  assert_true(sys.poll().length() == 0)
  sys.close()
}
