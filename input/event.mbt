// 输入事件跨平台抽象:按键/鼠标统一事件模型 + 键鼠状态聚合。
//
// 平台分工(Linux 真实现,Windows 占位):
//   - x11.mbt(#cfg 非 Windows):第二条 X 连接 + XSelectInput,每帧 poll()
//     把 KeyPress/KeyRelease/ButtonPress/ButtonRelease/MotionNotify 翻译成
//     InputEvent 队列,由宿主在渲染帧回调里取走(接进窗口事件循环)。
//   - windows.mbt(#cfg Windows):open_win32 占位,真实现待铺
//     (WM_KEYDOWN/WM_LBUTTONDOWN/WM_MOUSEMOVE/WM_MOUSEWHEEL → 同一套事件)。
//
// 状态(InputState)与事件(InputEvent)全平台一致;游戏逻辑只面向这两者。

///|
/// 抽象键码(平台键位翻译的目标)。字母/数字/常用功能键;未收录的键
/// 归入 Unknown(平台原始码低 32 位),状态跟踪自动忽略。
pub enum KeyCode {
  A
  B
  C
  D
  E
  F
  G
  H
  I
  J
  K
  L
  M
  N
  O
  P
  Q
  R
  S
  T
  U
  V
  W
  X
  Y
  Z
  Num0
  Num1
  Num2
  Num3
  Num4
  Num5
  Num6
  Num7
  Num8
  Num9
  Space
  Esc
  Enter
  Tab
  Backspace
  Left
  Up
  Right
  Down
  Shift
  Ctrl
  Alt
  Delete
  Unknown(Int)
}

///|
/// 键码总数(InputState 键位数组长度);Unknown 不入数组。
const KEY_CODE_COUNT : Int = 49

///|
/// 状态数组下标(字母 0..25、数字 26..35、功能键 36..48);Unknown 返回 -1
/// 表示不入状态数组。
pub fn KeyCode::index(self : KeyCode) -> Int {
  match self {
    A => 0
    B => 1
    C => 2
    D => 3
    E => 4
    F => 5
    G => 6
    H => 7
    I => 8
    J => 9
    K => 10
    L => 11
    M => 12
    N => 13
    O => 14
    P => 15
    Q => 16
    R => 17
    S => 18
    T => 19
    U => 20
    V => 21
    W => 22
    X => 23
    Y => 24
    Z => 25
    Num0 => 26
    Num1 => 27
    Num2 => 28
    Num3 => 29
    Num4 => 30
    Num5 => 31
    Num6 => 32
    Num7 => 33
    Num8 => 34
    Num9 => 35
    Space => 36
    Esc => 37
    Enter => 38
    Tab => 39
    Backspace => 40
    Left => 41
    Up => 42
    Right => 43
    Down => 44
    Shift => 45
    Ctrl => 46
    Alt => 47
    Delete => 48
    Unknown(_) => -1
  }
}

///|
/// 人类可读名(日志/控制台打印用)。
pub fn KeyCode::label(self : KeyCode) -> String {
  match self {
    A => "A"
    B => "B"
    C => "C"
    D => "D"
    E => "E"
    F => "F"
    G => "G"
    H => "H"
    I => "I"
    J => "J"
    K => "K"
    L => "L"
    M => "M"
    N => "N"
    O => "O"
    P => "P"
    Q => "Q"
    R => "R"
    S => "S"
    T => "T"
    U => "U"
    V => "V"
    W => "W"
    X => "X"
    Y => "Y"
    Z => "Z"
    Num0 => "0"
    Num1 => "1"
    Num2 => "2"
    Num3 => "3"
    Num4 => "4"
    Num5 => "5"
    Num6 => "6"
    Num7 => "7"
    Num8 => "8"
    Num9 => "9"
    Space => "Space"
    Esc => "Esc"
    Enter => "Enter"
    Tab => "Tab"
    Backspace => "Backspace"
    Left => "Left"
    Up => "Up"
    Right => "Right"
    Down => "Down"
    Shift => "Shift"
    Ctrl => "Ctrl"
    Alt => "Alt"
    Delete => "Delete"
    Unknown(code) => "Unknown(\{code})"
  }
}

///|
/// 鼠标键(滚轮不在此列:X11 的 Button4/5 翻译成 Wheel 事件)。
pub enum MouseButton {
  Left
  Middle
  Right
  /// 其他侧键(X11 button 6/7 已作横滚轮消费,8 及以上落此处)
  Other(Int)
}

///|
/// 状态数组下标(左 0 中 1 右 2);Other 不入状态数组返回 -1。
pub fn MouseButton::index(self : MouseButton) -> Int {
  match self {
    Left => 0
    Middle => 1
    Right => 2
    Other(_) => -1
  }
}

///|
/// X11 button 码 → 鼠标键(1=左 2=中 3=右;4-7 滚轮在泵里已消费)。
pub fn MouseButton::from_x(code : Int) -> MouseButton {
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
/// libyue 鼠标键 → 鼠标键(1=左 2=右 3=中,libyue 统一语义)。
pub fn MouseButton::from_yue(b : Int) -> MouseButton {
  if b == 1 {
    Left
  } else if b == 2 {
    Right
  } else if b == 3 {
    Middle
  } else {
    Other(b)
  }
}

///|
/// 鼠标键名(日志用)。
pub fn MouseButton::label(self : MouseButton) -> String {
  match self {
    Left => "Left"
    Middle => "Middle"
    Right => "Right"
    Other(n) => "Other(\{n})"
  }
}

///|
/// 输入事件(平台无关)。坐标一律取根窗口(root)坐标:X11 事件窗口
/// 可能是宿主容器或顶层窗,root 坐标在拖拽差分里与事件来源无关。
pub enum InputEvent {
  KeyDown(KeyCode)
  KeyUp(KeyCode)
  /// 按下:(键, 根坐标 x, 根坐标 y)
  MouseDown(MouseButton, Double, Double)
  /// 抬起:(键, 根坐标 x, 根坐标 y)
  MouseUp(MouseButton, Double, Double)
  /// 移动:(根坐标 x, 根坐标 y)
  MouseMove(Double, Double)
  /// 滚轮:(dx, dy);dy<0 向上滚(拉近),dy>0 向下滚(拉远),
  /// 对照 DOM WheelEvent.deltaY 的符号约定,可直接喂 OrbitControls::zoom
  Wheel(Double, Double)
}

///|
/// 事件构造器(枚举对外只读;宿主后端把平台事件翻译成 InputEvent 时用)
pub fn InputEvent::key_down(k : KeyCode) -> InputEvent {
  KeyDown(k)
}

///|
pub fn InputEvent::key_up(k : KeyCode) -> InputEvent {
  KeyUp(k)
}

///|
pub fn InputEvent::mouse_down(
  b : MouseButton,
  x : Double,
  y : Double,
) -> InputEvent {
  MouseDown(b, x, y)
}

///|
pub fn InputEvent::mouse_up(
  b : MouseButton,
  x : Double,
  y : Double,
) -> InputEvent {
  MouseUp(b, x, y)
}

///|
pub fn InputEvent::mouse_move(x : Double, y : Double) -> InputEvent {
  MouseMove(x, y)
}

///|
pub fn InputEvent::wheel(dx : Double, dy : Double) -> InputEvent {
  Wheel(dx, dy)
}

///|
/// 键鼠状态聚合:由事件流喂数,游戏逻辑每帧查询。
/// (键盘自动重复会生成 KeyDown/KeyUp 成对事件,净效果 is_down 保持 true。)
pub struct InputState {
  /// 键按下表(KeyCode::index 为下标;Unknown 不入)
  keys : FixedArray[Bool]
  /// 鼠标键按下表(MouseButton::index 为下标;Other 不入)
  buttons : FixedArray[Bool]
  mut mouse_x : Double
  mut mouse_y : Double
}

///|
/// 构造:全不按、指针 (0,0)。
pub fn InputState::new() -> InputState {
  {
    keys: FixedArray::make(KEY_CODE_COUNT, false),
    buttons: FixedArray::make(3, false),
    mouse_x: 0.0,
    mouse_y: 0.0,
  }
}

///|
/// 应用一个事件(滚轮不改变任何状态,只为接口统一)。
pub fn InputState::apply(self : InputState, ev : InputEvent) -> Unit {
  match ev {
    KeyDown(k) => {
      let i = k.index()
      if i >= 0 {
        self.keys[i] = true
      }
    }
    KeyUp(k) => {
      let i = k.index()
      if i >= 0 {
        self.keys[i] = false
      }
    }
    MouseDown(b, _, _) => {
      let i = b.index()
      if i >= 0 {
        self.buttons[i] = true
      }
    }
    MouseUp(b, _, _) => {
      let i = b.index()
      if i >= 0 {
        self.buttons[i] = false
      }
    }
    MouseMove(x, y) => {
      self.mouse_x = x
      self.mouse_y = y
    }
    Wheel(_, _) => ()
  }
}

///|
/// 键当前是否按下(Unknown 恒 false)。
pub fn InputState::is_down(self : InputState, key : KeyCode) -> Bool {
  let i = key.index()
  i >= 0 && self.keys[i]
}

///|
/// 鼠标键当前是否按下(Other 恒 false)。
pub fn InputState::is_button_down(self : InputState, b : MouseButton) -> Bool {
  let i = b.index()
  i >= 0 && self.buttons[i]
}

///|
/// 指针 root 坐标。
pub fn InputState::mouse_pos(self : InputState) -> (Double, Double) {
  (self.mouse_x, self.mouse_y)
}

///|
/// WASD 移动轴:(dx, dz)。dx = D - A(右 +1/左 -1),dz = S - W
/// (后 +1/前 -1,屏幕上向下为后,与三维地形端 main.js 的 z 轴语义一致)。
pub fn InputState::move_axis(self : InputState) -> (Double, Double) {
  let mut dx = 0.0
  let mut dz = 0.0
  if self.is_down(D) {
    dx = dx + 1.0
  }
  if self.is_down(A) {
    dx = dx - 1.0
  }
  if self.is_down(S) {
    dz = dz + 1.0
  }
  if self.is_down(W) {
    dz = dz - 1.0
  }
  (dx, dz)
}

///|
/// 当前按下的键列表(按状态数组序;日志用)。
pub fn InputState::pressed_keys(self : InputState) -> Array[String] {
  let out : Array[String] = []
  for i, down in self.keys {
    if down {
      out.push(key_from_index(i).label())
    }
  }
  out
}

///|
/// index → 键码(pressed_keys 用;越界返回 Unknown(-1),不对外承诺)。
fn key_from_index(i : Int) -> KeyCode {
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
    25 => Z
    26 => Num0
    27 => Num1
    28 => Num2
    29 => Num3
    30 => Num4
    31 => Num5
    32 => Num6
    33 => Num7
    34 => Num8
    35 => Num9
    36 => Space
    37 => Esc
    38 => Enter
    39 => Tab
    40 => Backspace
    41 => Left
    42 => Up
    43 => Right
    44 => Down
    45 => Shift
    46 => Ctrl
    47 => Alt
    48 => Delete
    _ => Unknown(-1)
  }
}

///|
/// 输入泵句柄(跨平台抽象的类型面;字段仅包内使用)。
///
/// Linux:open_x11() 建第二条 X 连接(独立于 GTK 主连接,互不抢事件),
/// watch_xids 是要监听输入的窗口 XID(顶层窗 + 3D 宿主容器都传,键盘
/// 落焦点窗、鼠标落指针下窗口);poll() 每帧把队列取走。
/// Windows:open_win32() 占位待铺。
pub struct InputSystem {
  /// 平台句柄:Linux = 专用输入线程泵句柄;Windows 占位恒 0
  dpy : UInt64
  /// 监听输入的窗口 XID 列表(Linux)
  watch_xids : Array[UInt64]
  /// 泵记录批量取出缓冲(32B × 256 条;open 时分配)
  buf : Bytes
  /// 单条记录复用缓冲(语义占位;记录直接在 buf 内解析)
  xi_buf : Bytes
  /// close 后 poll 即为空
  mut alive : Bool
}

///|
/// 根窗口 XID(无宿主句柄的独立进程挂事件用;临时开一条连接查询)。
pub fn InputSystem::default_root_xid() -> UInt64 {
  let dpy = sf_x11_open_display()
  if dpy == 0UL {
    return 0UL
  }
  let root = sf_x11_default_root_window(dpy)
  sf_x11_close_display(dpy)
  root
}
