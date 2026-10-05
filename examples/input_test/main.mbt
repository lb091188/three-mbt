// input_test:A9 输入泵 + 相机控制器端到端示例。
// 链路:yue 窗口(窗口壳)→ GDK 取 host/顶层 XID → input::open_x11 开
// 第二条 X 连接收 KeyPress/KeyRelease/ButtonPress/ButtonRelease/
// MotionNotify/滚轮 → 每帧(16ms timer)poll 事件队列 → WASD 移动箱子、
// 左键拖拽转 Orbit 相机、滚轮缩放、ESC 退出。
// 环境变量:
//   INPUT_TEST_MAX_FRAMES  帧数上限(默认 900 ≈ 15s,到帧正常退出)
//   INPUT_TEST_SHOT_FRAME  截图帧(默认 480 ≈ 8s,import -window root)
// 控制台打印:按键按/放即时打印,每 60 帧一行状态汇总(keys/箱位/相机眼点)。

///|
#borrow(widget)
extern "c" fn ffi_gtk_widget_get_window(widget : UInt64) -> UInt64 = "gtk_widget_get_window"

///|
#borrow(gdkwin)
extern "c" fn ffi_gdk_window_get_display(gdkwin : UInt64) -> UInt64 = "gdk_window_get_display"

///|
#borrow(gdkwin)
extern "c" fn ffi_gdk_x11_window_get_xid(gdkwin : UInt64) -> UInt = "gdk_x11_window_get_xid"

///|
#borrow(display)
extern "c" fn ffi_gdk_x11_display_get_xdisplay(display : UInt64) -> UInt64 = "gdk_x11_display_get_xdisplay"

///|
#borrow(gdkwin)
extern "c" fn ffi_gdk_window_get_toplevel(gdkwin : UInt64) -> UInt64 = "gdk_window_get_toplevel"

///|
#borrow(cmd)
extern "c" fn c_system(cmd : Bytes) -> Int = "system"

// 直接文件日志(fopen/fputs/fflush):moon 原生 stdout 在重定向下全缓冲,
// 应用不退出就一行都看不到;驱动验证要每行实时落盘。

///|
#borrow(path, mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///|
#borrow(s)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

///|
extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///|
let log_file : Ref[UInt64] = Ref(0)

///|
/// 打印并落盘一行(应用退出前也能实时看到)。
fn logln(s : String) -> Unit {
  println(s)
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  if log_file.val == 0 {
    log_file.val = c_fopen(b"/tmp/input_test_app.log\x00", b"w\x00")
  }
  if log_file.val != 0 {
    ignore(c_fputs(line, log_file.val))
    ignore(c_fflush(log_file.val))
  }
}

///|
/// 纯数字十进制串 → UInt64(外部窗口 XID 解析)
fn parse_dec_xid(s : String) -> UInt64 {
  let mut acc : UInt64 = 0UL
  let n = s.char_length()
  for i in 0..<n {
    let c = s.unsafe_get(i).to_int()
    if c >= 48 && c <= 57 {
      acc = acc * 10UL + (c - 48).to_uint64()
    }
  }
  acc
}

///|
/// 纯数字十进制串 → Int(obj.mbt 同式逐位解析;负数/含其他字符视为缺省)
fn parse_int_simple(s : String) -> Int? {
  let n = s.char_length()
  if n == 0 {
    return None
  }
  let mut acc = 0
  for i in 0..<n {
    let c = s.unsafe_get(i).to_int()
    if c < 48 || c > 57 {
      return None
    }
    acc = acc * 10 + (c - 48)
  }
  Some(acc)
}

///|
fn env_int(name : String, fallback : Int) -> Int {
  match @env.get_env_var(name) {
    Some(s) => parse_int_simple(s).unwrap_or(fallback)
    None => fallback
  }
}

///|
fn main raise {
  if !@yue.initialize() {
    println("init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("input-test")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(640.0, 480.0)
  window.activate()
  // 计数与状态(退出 SUMMARY 汇报)
  let key_downs = Ref(0)
  let key_ups = Ref(0)
  let wheels = Ref(0)
  let drags = Ref(0)
  let frame = Ref(0)
  let viewport_h = Ref(480.0)
  let shot_done = Ref(false)
  let max_frames = env_int("INPUT_TEST_MAX_FRAMES", 900)
  let bail_ms = env_int("INPUT_TEST_BAIL_MS", 25000)
  let shot_frame = env_int("INPUT_TEST_SHOT_FRAME", 480)
  // 场景:动箱(橙,WASD)+ 静箱(灰蓝,参照物)
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let box_moving = @core.Mesh::new(
    @core.BufferGeometry::box(1.5, 1.5, 1.5),
    @core.Material::basic(@math3d.Color::from_hex("#f59e0b").unwrap()),
  )
  box_moving.position = @math3d.Vector3::new(0.0, 0.75, 0.0)
  scene.add(box_moving)
  let box_static = @core.Mesh::new(
    @core.BufferGeometry::box(1.5, 1.5, 1.5),
    @core.Material::basic(@math3d.Color::from_hex("#64748b").unwrap()),
  )
  box_static.position = @math3d.Vector3::new(4.0, 0.75, -2.0)
  scene.add(box_static)
  // 相机 + 轨道控制器(绕点环绕 + 滚轮缩放)
  let camera = @core.PerspectiveCamera::new(60.0, 640.0 / 480.0, 0.1, 100.0)
  let orbit = @controls.OrbitControls::new()
  orbit.target = @math3d.Vector3::new(0.0, 0.75, 0.0)
  orbit.min_distance = 2.0
  orbit.max_distance = 40.0
  let eye0 = @math3d.Vector3::new(0.0, 3.0, 9.0)
  camera.look_at(eye0, orbit.target)
  // 输入状态聚合(事件流喂入,逻辑查询)
  let state = @input.InputState::new()
  // 拖拽态(鼠标事件驱动 Orbit)
  let dragging = Ref(false)
  let last_x = Ref(0.0)
  let last_y = Ref(0.0)
  // 渲染器/输入泵引用(post_task 里建好;先声明供 resize 回调捕获)
  let renderer_ref : Ref[@renderers.WebGPURenderer?] = Ref(None)
  let input_ref : Ref[@input.InputSystem?] = Ref(None)
  // 事件处理:键盘/鼠标按放与滚轮即时打印,喂状态聚合与控制器
  let handle_event = fn(ev : @input.InputEvent) -> Bool {
    // 返回 false = 要求退出(ESC)
    match ev {
      KeyDown(k) => {
        key_downs.val = key_downs.val + 1
        logln("KEY down \{k.label()}")
        state.apply(ev)
        k is Esc
      }
      KeyUp(k) => {
        key_ups.val = key_ups.val + 1
        logln("KEY up \{k.label()}")
        state.apply(ev)
        false
      }
      MouseDown(b, x, y) => {
        logln("MOUSE down \{b.label()} @(\{x},\{y})")
        state.apply(ev)
        if b is Left {
          dragging.val = true
          last_x.val = x
          last_y.val = y
        }
        false
      }
      MouseUp(b, x, y) => {
        logln("MOUSE up \{b.label()} @(\{x},\{y})")
        state.apply(ev)
        if b is Left {
          dragging.val = false
        }
        false
      }
      MouseMove(x, y) => {
        state.apply(ev)
        if dragging.val {
          drags.val = drags.val + 1
          let dx = x - last_x.val
          let dy = y - last_y.val
          // 拖满一个视口高度旋转一圈(three.js OrbitControls 换算)
          orbit.rotate(dx, dy, viewport_h.val)
          logln("MOUSE drag d=(\{dx},\{dy}) 已拖 \{drags.val} 次")
        }
        last_x.val = x
        last_y.val = y
        false
      }
      Wheel(dx, dy) => {
        wheels.val = wheels.val + 1
        orbit.zoom(dy)
        logln("WHEEL d=(\{dx},\{dy})")
        false
      }
    }
  }
  // keys 数组拼接(状态行用)
  let keys_str = fn(arr : Array[String]) -> String {
    let mut out = ""
    for i, k in arr {
      if i > 0 {
        out = out + "+"
      }
      out = out + k
    }
    out
  }
  host.on_size_changed(fn() {
    let b = host.get_bounds()
    viewport_h.val = b.height
    match renderer_ref.val {
      Some(r) => r.resize(b.width.to_uint(), b.height.to_uint())
      None => ()
    }
  })
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      logln("host 控件未 realize")
      return
    }
    let host_xid = ffi_gdk_x11_window_get_xid(gdkwin).to_uint64()
    let toplevel_gdk = ffi_gdk_window_get_toplevel(gdkwin)
    let toplevel_xid = ffi_gdk_x11_window_get_xid(toplevel_gdk).to_uint64()
    // 十进制打印(与 xdotool/wmctrl 的十进制 id 直接对得上)
    logln("XID host=\{host_xid} toplevel=\{toplevel_xid}")
    // 第二条 X 连接收输入(顶层窗 + host 容器都挂:键盘落焦点窗,
    // 鼠标落指针下窗口;INPUT_TEST_WATCH_ROOT=1 时加挂根窗口做对照)
    let backend = @env.get_env_var("INPUT_TEST_BACKEND").unwrap_or("yue")
    logln("backend=\{backend}")
    if backend == "yue" {
      // yue 后端:键盘/鼠标走 Window 级宿主事件(真机对照:Window 级
      // win_down=1 而 Container 级 host_down=0,input_diag 同现象),翻译
      // 成同一套 InputEvent 喂 handle_event;X11 泵在 GTK 宿主进程内被
      // 进程级因素阻断(见 input 包 x11.mbt 文档),独立宿主用 x11 模式。
      window.on_key_down(fn(kev) {
        let ev = @input.InputEvent::key_down(
          @input.keysym_to_keycode(kev.code.to_uint64()),
        )
        if handle_event(ev) {
          logln("ESC → 退出")
          @yue.quit()
        }
        false
      })
      window.on_key_up(fn(kev) {
        let ev = @input.InputEvent::key_up(
          @input.keysym_to_keycode(kev.code.to_uint64()),
        )
        if handle_event(ev) {
          @yue.quit()
        }
        false
      })
      window.on_mouse_down(fn(me) {
        let ev = @input.InputEvent::mouse_down(
          @input.MouseButton::from_yue(me.button),
          me.screen_x,
          me.screen_y,
        )
        if handle_event(ev) {
          @yue.quit()
        }
        false
      })
      window.on_mouse_up(fn(me) {
        let ev = @input.InputEvent::mouse_up(
          @input.MouseButton::from_yue(me.button),
          me.screen_x,
          me.screen_y,
        )
        if handle_event(ev) {
          @yue.quit()
        }
        false
      })
      window.on_mouse_move(fn(me) {
        ignore(
          handle_event(@input.InputEvent::mouse_move(me.screen_x, me.screen_y)),
        )
      })
      // motion 双挂(host + window):不同 GTK 版本只投其一;拖拽差分对
      // 重复事件天然幂等(第二份 delta=0)
      host.on_mouse_move(fn(me) {
        ignore(
          handle_event(@input.InputEvent::mouse_move(me.screen_x, me.screen_y)),
        )
      })
      window.on_wheel(fn(d) {
        // yue 的 d ≈ ±1/格;Wheel 约定 DOM deltaY 尺度 ±100/格
        ignore(handle_event(@input.InputEvent::wheel(0.0, d * 100.0)))
      })
    } else {
      // x11 后端:第二条 X 连接 + XI2 泵(独立进程/非 GTK 宿主)。
      // 监听窗口:顶层窗 + host 容器都挂(键盘落焦点窗、鼠标落指针下
      // 窗口);INPUT_TEST_WATCH_ROOT=1 / INPUT_TEST_EXT_XID 为诊断项。
      let watch = [toplevel_xid, host_xid]
      if @env.get_env_var("INPUT_TEST_WATCH_ROOT") == Some("1") {
        let root = @input.InputSystem::default_root_xid()
        if root != 0UL {
          watch.push(root)
          logln("watch root=\{root}")
        }
      }
      match @env.get_env_var("INPUT_TEST_EXT_XID") {
        Some(sv) => {
          let ext = parse_dec_xid(sv)
          if ext != 0UL {
            watch.push(ext)
            logln("watch ext=\{ext}")
          }
        }
        None => ()
      }
      let input = @input.InputSystem::open_x11(watch) catch {
        e => {
          logln("输入泵建立失败 \{e}")
          return
        }
      }
      input_ref.val = Some(input)
    }
    let renderer = @renderers.WebGPURenderer::from_xlib(
      ffi_gdk_x11_display_get_xdisplay(ffi_gdk_window_get_display(gdkwin)),
      host_xid,
      640U,
      480U,
    ) catch {
      e => {
        logln("渲染器建立失败 \{e}")
        return
      }
    }
    renderer_ref.val = Some(renderer)
    logln("input_test:渲染循环启动(ESC 或 \{max_frames} 帧退出)")
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      // ① 本帧事件:输入泵接进窗口事件循环的位置(x11 后端;yue 后端
      // 事件由宿主回调直接喂入)
      match input_ref.val {
        Some(input) => {
          let events = input.poll()
          for ev in events {
            if handle_event(ev) {
              logln("ESC → 退出")
              input.close()
              @yue.quit()
              return false
            }
          }
        }
        None => ()
      }
      // ② 逻辑:WASD 移动箱子(世界轴,speed 3 m/s)
      let (mdx, mdz) = state.move_axis()
      if mdx != 0.0 || mdz != 0.0 {
        let dt = 1.0 / 60.0
        let speed = 3.0
        box_moving.position = @math3d.Vector3::new(
          box_moving.position.x + mdx * speed * dt,
          box_moving.position.y,
          box_moving.position.z + mdz * speed * dt,
        )
      }
      // ③ 相机:轨道增量应用(拖拽/滚轮已喂入)
      orbit.update(camera)
      // ④ 渲染
      match renderer_ref.val {
        Some(r) =>
          r.render(scene, camera) catch {
            e => {
              logln("渲染失败 \{e}")
              return false
            }
          }
        None => ()
      }
      // ⑤ 状态行(每 60 帧):按键状态 + 箱位 + 相机眼点
      if frame.val % 60 == 0 {
        let keys = keys_str(state.pressed_keys())
        let p = box_moving.position
        let e = camera.obj.position
        let pending = match input_ref.val {
          Some(i) => i.debug_pending()
          None => -9
        }
        logln(
          "STATE t=\{Int::to_double(frame.val) / 60.0}s keys=[\{keys}] box=(\{p.x},\{p.z}) eye=(\{e.x},\{e.y},\{e.z}) pending=\{pending}",
        )
      }
      // ⑥ 截图帧(真机取证,裁剪后自查)
      if frame.val == shot_frame && !shot_done.val {
        shot_done.val = true
        let cmd : Bytes = @utf8.encode(
            "import -window root /tmp/input_test_raw.png 2>/tmp/input_test_shot.err",
          ) +
          b"\x00"
        let rc = c_system(cmd)
        logln("截图 rc=\{rc}(frame \{shot_frame})→ /tmp/input_test_raw.png")
      }
      // ⑦ 帧数上限:正常退出
      if frame.val >= max_frames {
        let p = box_moving.position
        let e = camera.obj.position
        logln(
          "SUMMARY frames=\{frame.val} key_downs=\{key_downs.val} key_ups=\{key_ups.val} wheels=\{wheels.val} drags=\{drags.val} box=(\{p.x},\{p.z}) eye=(\{e.x},\{e.y},\{e.z})",
        )
        match input_ref.val {
          Some(i) => i.close()
          None => ()
        }
        @yue.quit()
        return false
      }
      true
    })
  })
  // 兜底退出(默认 25s;INPUT_TEST_BAIL_MS 可调,防止任何卡态占住窗口)
  @yue.set_timer(bail_ms, fn() {
    logln("兜底退出")
    match input_ref.val {
      Some(i) => i.close()
      None => ()
    }
    @yue.quit()
    false
  })
  @yue.run()
}
