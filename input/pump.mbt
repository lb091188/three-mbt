// 专用输入线程(Linux):第二条 X 连接由该线程独占打开与读取,绕开
// 宿主(GDK/glib 主循环)对调用线程 Xlib 状态的干扰(实测:同进程内
// 主线程开第二条连接挂 XI2,XPending 恒 0;独立进程同代码正常)。
// 线程只做"取事件 → 打包字段"(evtype/detail/keysym/root_x/root_y),
// InputEvent 的翻译留在 MoonBit 纯函数 decode_record(单测覆盖)。
//
// 记录 32 字节定长:[evtype i32][detail i32][keysym u64][rx f64][ry f64]
// evtype 用 XI2 值(2..6,与 core 同值);滚轮=button 4..7,翻译同 core。

///|
/// 泵记录字节长。
const PUMP_REC : Int = 32

///|
/// 泵单帧最大取出条数。
const PUMP_BATCH : Int = 256

///|
/// 打开输入泵:建立专用线程,线程内 XOpenDisplay + XI2 选择 + 阻塞读取,
/// 打包记录进环形队列。watch_xids = 监听的窗口 XID(可为空,后续用
/// watch 加挂)。返回句柄为 0 表示启动失败(无 libX11/XI2 或线程失败)。
#cfg(not(platform="windows"))
pub fn InputSystem::open_x11(
  watch_xids : Array[UInt64],
) -> InputSystem raise Error {
  // 编码 XID 列表为字节流(LE u64 数组)
  let n = watch_xids.length()
  let arg = Bytes::makei(8 * n, fn(i) {
    let v = watch_xids[i / 8]
    let b = i % 8
    ((v >> (b * 8)) & 0xFFUL).to_int().to_byte()
  })
  let pump = sf_x11_pump_start(arg, n)
  if pump == 0UL {
    raise Failure(
      "X11 输入泵:无法打开显示连接(libX11/libXi 缺失、DISPLAY 未设置或线程启动失败)",
    )
  }
  {
    dpy: pump,
    watch_xids,
    buf: Bytes::make(PUMP_REC * PUMP_BATCH, 0),
    xi_buf: Bytes::make(PUMP_REC, 0),
    alive: true,
  }
}

///|
/// 取走并清空本帧事件队列(每帧调用一次,典型在渲染帧回调开头)。
/// 单帧上限 256 条是卡帧保险:超量说明事件风暴,丢帧好过卡死。
#cfg(not(platform="windows"))
pub fn InputSystem::poll(self : InputSystem) -> Array[InputEvent] {
  let out : Array[InputEvent] = []
  if !self.alive || self.dpy == 0UL {
    return out
  }
  let n = sf_x11_pump_take(self.dpy, self.buf, PUMP_BATCH)
  for i in 0..<n {
    let off = i * PUMP_REC
    let evtype = i32_le(self.buf, off)
    let detail = i32_le(self.buf, off + 4)
    let keysym = u64_le(self.buf, off + 8)
    let rx = sf_x11_bits_to_f64(f64_bits(self.buf, off + 16))
    let ry = sf_x11_bits_to_f64(f64_bits(self.buf, off + 24))
    match decode_record(evtype, detail, keysym, rx, ry) {
      Some(ev) => out.push(ev)
      None => ()
    }
  }
  out
}

///|
/// 诊断:泵队列当前积压条数。
#cfg(not(platform="windows"))
pub fn InputSystem::debug_pending(self : InputSystem) -> Int {
  if !self.alive || self.dpy == 0UL {
    return -1
  }
  sf_x11_pump_qlen(self.dpy)
}

///|
/// 关闭输入泵(幂等;停线程、关连接)。
#cfg(not(platform="windows"))
pub fn InputSystem::close(self : InputSystem) -> Unit {
  if self.alive {
    self.alive = false
    if self.dpy != 0UL {
      sf_x11_pump_stop(self.dpy)
    }
  }
}
