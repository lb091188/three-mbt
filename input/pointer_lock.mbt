// 指针锁定(FPS 式)机制层 —— 常规端游做法:
//   点击进入锁定(点击窗口抓捕指针,光标隐藏)+ 锁定中鼠标移动按
//   "对窗口中心的位移差分"驱动视角 + 每事件回中(无限相对移动)+
//   ESC/失焦自动释放。"何时锁定"是游戏侧策略,本层只给机制。
//
// X11 实现要点(与 x11.mbt 泵的"第二连接教训"不冲突):
//   grab/warp/焦点查询是命令型请求-回复,不依赖事件投递,直接在宿主
//   (GDK)自己的 display 上、主线程内调用即可;owner_events=1 且抓捕
//   窗口属本进程,宿主照常收到 motion(yue on_mouse_move 不受影响)。
//   XGrabPointer 的 cursor 参数传隐形光标,隐藏指针随抓捕建立/解除。
//
// Windows:垫片给 no-op,attach 返回 None(正路 ClipCursor+重定中心,
// 与 renderers::from_hwnd 同批铺设)。

///|
/// 一个窗口的指针锁定器。attach 后未 acquire 前不产生任何 X 副作用。
pub struct PointerLock {
  dpy : UInt64
  win : UInt64
  mut cx : Int
  mut cy : Int
  mut locked : Bool
  mut last_status : Int // 最近一次 acquire 的 XGrabPointer 返回码(诊断)
}

///|
/// 绑定到宿主 display 的指定窗口(display 传宿主自己的指针,如 GDK 的
/// xdisplay —— renderers::from_xlib 的取法;xid 同源)。X11 不可用
/// (无 libX11 / Windows)或参数无效返回 None。
pub fn PointerLock::attach(
  xdisplay : UInt64,
  xid : UInt,
  width : Int,
  height : Int,
) -> PointerLock? {
  if xdisplay == 0 || xid == 0U || width <= 0 || height <= 0 {
    return None
  }
  if sf_x11_load_libs() == 0 {
    return None
  }
  Some({
    dpy: xdisplay,
    win: xid.to_uint64(),
    cx: width / 2,
    cy: height / 2,
    locked: false,
    last_status: -1,
  })
}

///|
/// 抓捕指针(隐形光标 + confine 到窗口)并回中。成功 true。
pub fn PointerLock::acquire(self : PointerLock) -> Bool {
  let r = sf_x11_grab_pointer(self.dpy, self.win)
  self.last_status = r
  if r == 0 {
    self.locked = true
    self.recentre()
    true
  } else {
    false
  }
}

///|
/// 最近一次 acquire 的 XGrabPointer 返回码: 0=成功, 1=AlreadyGrabbed
/// (他人/隐式抓捕中, 常见于按钮按住瞬间), 2=GrabInvalidTime,
/// 3=GrabNotViewable(窗口未映射, 常见于切换动画中), 4=GrabFrozen。
pub fn PointerLock::last_grab_status(self : PointerLock) -> Int {
  self.last_status
}

///|
/// 释放抓捕(恢复光标);幂等。
pub fn PointerLock::release(self : PointerLock) -> Unit {
  if self.locked {
    ignore(sf_x11_ungrab_pointer(self.dpy))
    self.locked = false
  }
}

///|
/// 窗口尺寸变化时同步回中锚点。
pub fn PointerLock::update_size(
  self : PointerLock,
  width : Int,
  height : Int,
) -> Unit {
  if width > 0 && height > 0 {
    self.cx = width / 2
    self.cy = height / 2
  }
}

///|
/// 视角差分:事件坐标对窗口中心;恰好落在中心(回中产生的 motion 回声)
/// 返回 None 应忽略。取到 Some 后游戏应消费差分并调用 recentre()。
pub fn PointerLock::delta(
  self : PointerLock,
  x : Double,
  y : Double,
) -> (Double, Double)? {
  let dx = x - Double::from_int(self.cx)
  let dy = y - Double::from_int(self.cy)
  if dx == 0.0 && dy == 0.0 {
    None
  } else {
    Some((dx, dy))
  }
}

///|
/// 指针瞬移回窗口中心。
pub fn PointerLock::recentre(self : PointerLock) -> Unit {
  sf_x11_warp_pointer_window(self.dpy, self.win, self.cx, self.cy)
}

///|
/// 轮询采样(tick 驱动,约 60Hz):返回 (dx, dy, btn1)。dx/dy 是事件坐标
/// 对窗口中心的差分(0/0=静止或回中回声,应跳过视角更新);btn1=左键
/// 按住(core grab 会抑制宿主 XI2 事件投递,按钮状态一并轮询补位)。
/// 消费非零差分后调用方应 recentre()。X11 不可用返回全零。
pub fn PointerLock::poll(self : PointerLock) -> (Double, Double, Bool) {
  let buf = Bytes::makei(12, _ => b'\x00')
  if sf_x11_query_pointer(self.dpy, self.win, buf) == 0 {
    return (0.0, 0.0, false)
  }
  let wx = read_i32_le(buf, 0)
  let wy = read_i32_le(buf, 4)
  let btn1 = read_i32_le(buf, 8) != 0
  (Double::from_int(wx - self.cx), Double::from_int(wy - self.cy), btn1)
}

///|
fn read_i32_le(b : Bytes, off : Int) -> Int {
  let mut v = 0
  for i in 0..<4 {
    v = v | (b[off + i].to_int() << (i * 8))
  }
  v
}

///|
/// 键盘焦点仍在锁定窗口或其祖先?(端游铁律:失焦必须自动释放。)
/// 判定顺序:①EWMH _NET_ACTIVE_WINDOW —— Mutter 把 XGetInputFocus 放在
/// 独立 WM 辅助窗口(实测=客户窗口 XID+1),祖先链比对必误判,活动窗口
/// 才是客户顶层口径;②无 EWMH 回退 XGetInputFocus 沿父链上溯比对。
pub fn PointerLock::focused(self : PointerLock) -> Bool {
  let active = sf_x11_active_window(self.dpy)
  if active > 1 && self.in_ancestry(active) {
    return true
  }
  let focus = sf_x11_input_focus_window(self.dpy)
  if focus == 0 || focus == 1 {
    // None/PointerRoot:焦点不在具体窗口,按失焦处理(宁多释放不吞指针)
    return false
  }
  self.in_ancestry(focus)
}

///|
/// target 是否为锁定窗口自身或其祖先(≤32 跳,环与超深保护)。
fn PointerLock::in_ancestry(self : PointerLock, target : UInt64) -> Bool {
  if target == self.win {
    return true
  }
  let mut w = self.win
  let mut depth = 0
  while w != 0 && w != 1 && depth < 32 {
    w = sf_x11_window_parent(self.dpy, w)
    if w == target {
      return true
    }
    depth = depth + 1
  }
  false
}

///|
/// 当前是否处于锁定态(机制状态;策略侧以此分流输入)。
pub fn PointerLock::is_locked(self : PointerLock) -> Bool {
  self.locked
}

///|
/// 失焦判定诊断(验收/排障用):焦点窗口 + 锁定窗口起父链各 8 跳。
pub fn PointerLock::debug_focus_chain(self : PointerLock) -> String {
  let focus = sf_x11_input_focus_window(self.dpy)
  let mut s = "focus=0x\{focus.to_string()}"
  s = s + " win=0x\{self.win.to_string()}"
  let mut w = self.win
  for i in 0..<8 {
    w = sf_x11_window_parent(self.dpy, w)
    s = s + " p\{i}=0x\{w.to_string()}"
    if w <= 1 {
      break
    }
  }
  s
}
