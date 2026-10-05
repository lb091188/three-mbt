// 实验 A:async external_loop_integration 嵌 yue 主循环(Windows 首验)。
// 形态:async fn main 里建 yue 窗口,set_external_event_loop(YueLoop),
// async 的等待线程收 IOCP 网络事件,主线程 poll() 泵 yue 消息
// (MsgWait 唤醒事件+GUI 输入 → PeekMessage 全量派发)。
// 验证目标:①async 定时器/网络任务在 GUI 存活期间推进;②yue 鼠标事件
// 在 poll 泵期间到达;③干净退出。证据走文件日志(每行 fflush)。

extern "c" fn c_poll(t : Int) -> Unit = "yue_async_int_poll"

extern "c" fn c_wake() -> Unit = "yue_async_int_wake"

#borrow(path)
#borrow(mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

#borrow(s)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///| 文件日志(yue-int.log,工作目录),立即落盘
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(
    b"yue-int.log\x00",
    b"a\x00",
  )
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

///|
pub fn YueLoop::make() -> YueLoop {
  { dummy: () }
}

///|
struct YueLoop {
  dummy : Unit
}

///|
using @external_loop_integration {trait ExternalEventLoop}

///|
pub impl ExternalEventLoop for YueLoop with fn get_wakeup_callback_for_foreign_thread(
  _self,
) {
  () => c_wake()
}

///|
pub impl ExternalEventLoop for YueLoop with fn poll(_self, timeout?) {
  let t = match timeout {
    Some(v) => v
    None => -1
  }
  c_poll(t)
}

///|
pub impl ExternalEventLoop for YueLoop with fn terminate(_self) {
  logln("loop: terminate")
}

///| 共享状态:async 任务与 yue 回调同在主线程,直接读写
struct App {
  clicks : Ref[Int]
  ticks : Ref[Int]
  tcp_reply : Ref[String]
  quit : Ref[Bool]
}

///|
let app : App = {
  clicks: Ref(0),
  ticks: Ref(0),
  tcp_reply: Ref(""),
  quit: Ref(false),
}

///|
let label : Ref[@yue.Label?] = Ref(None)

///|
fn refresh_label() -> Unit {
  match label.val {
    Some(l) => {
      l.set_text("ticks=\{app.ticks.val} clicks=\{app.clicks.val} tcp=\{app.tcp_reply.val}")
    }
    None => ()
  }
}

///|
async fn main {
  logln("=== yue-async integration start ===")
  if !@yue.initialize() {
    logln("yue init failed")
    return
  }
  let window = @yue.Window::new()
  window.set_title("yue-async-int")
  let host = @yue.Container::new()
  window.set_content(host)
  let l = @yue.Label::new("booting...")
  host.add_child(l)
  label.val = Some(l)
  window.set_content_size(420.0, 160.0)
  window.center()
  window.activate()
  window.on_mouse_down(fn(_e) {
    app.clicks.val = app.clicks.val + 1
    refresh_label()
    false
  })
  window.on_close(fn(_w) {
    logln("gui: close requested")
    app.quit.val = true
  })
  // 必须在跑任何真实 async 代码前挂外部循环
  @async.set_external_event_loop(YueLoop::make())
  @async.with_task_group(group => {
    // ① 本机 TCP echo:server accept → 读 → 原样回写
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _addr) = server.accept()
      defer conn.close()
      match conn.read_some() {
        Some(b) => {
          logln("tcp: server got \{@utf8.decode(b)}")
          conn.write(@utf8.decode(b))
        }
        None => logln("tcp: server conn closed")
      }
    })
    // ② 客户端 300ms 后连接/发送/收回显
    group.spawn_bg(() => {
      @async.sleep(300)
      let c = @socket.Tcp::connect(server.addr)
      defer c.close()
      c.write("ping-async-yue")
      match c.read_some() {
        Some(b) => {
          app.tcp_reply.val = @utf8.decode(b)
          logln("tcp: client got echo \{app.tcp_reply.val}")
          refresh_label()
        }
        None => logln("tcp: client got EOF")
      }
    })
    // ③ async 定时器:500ms 一拍,更新 GUI 标签
    group.spawn_bg(() => {
      for i in 0..<12 {
        @async.sleep(500)
        app.ticks.val = i + 1
        refresh_label()
        logln("tick #\{i + 1}")
      }
    })
    // ④ 6.5s 后收摊
    group.spawn_bg(() => {
      @async.sleep(6500)
      logln("lifecycle: time up, quit")
      app.quit.val = true
    })
    // 主循环:async 等待期间 poll 泵 yue 消息
    while !app.quit.val {
      @async.sleep(50)
    }
  })
  logln(
    "=== done ticks=\{app.ticks.val} clicks=\{app.clicks.val} tcp=\{app.tcp_reply.val} ===",
  )
}
