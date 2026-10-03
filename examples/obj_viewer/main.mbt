// obj_viewer:OBJ 加载器 + 轨道相机端到端示例——yue 窗口里渲染一个
// 内置 OBJ 文本(24 顶点立方体,不读文件),左键拖拽旋转、滚轮缩放
// (OrbitControls 纯逻辑,由鼠标事件喂增量),15 秒自动退出。

// GDK/X11 换算(gdk 符号在 yue 的链接闭包内)
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

///| 内置立方体 OBJ(24 顶点、6 个四边面,覆盖 v/vt/vn 属性与

///|
/// v/vt/vn 面格式、任意多边形扇形三角化)
let builtin_obj : String =
  #|
  #|# three-native obj_viewer builtin cube (parsed in-place, no file IO)
  #|v -0.6 -0.6 0.6
  #|v 0.6 -0.6 0.6
  #|v 0.6 0.6 0.6
  #|v -0.6 0.6 0.6
  #|v 0.6 -0.6 -0.6
  #|v -0.6 -0.6 -0.6
  #|v -0.6 0.6 -0.6
  #|v 0.6 0.6 -0.6
  #|v 0.6 -0.6 0.6
  #|v 0.6 -0.6 -0.6
  #|v 0.6 0.6 -0.6
  #|v 0.6 0.6 0.6
  #|v -0.6 -0.6 -0.6
  #|v -0.6 -0.6 0.6
  #|v -0.6 0.6 0.6
  #|v -0.6 0.6 -0.6
  #|v -0.6 0.6 0.6
  #|v 0.6 0.6 0.6
  #|v 0.6 0.6 -0.6
  #|v -0.6 0.6 -0.6
  #|v -0.6 -0.6 -0.6
  #|v 0.6 -0.6 -0.6
  #|v 0.6 -0.6 0.6
  #|v -0.6 -0.6 0.6
  #|vt 0 1
  #|vt 1 1
  #|vt 1 0
  #|vt 0 0
  #|vn 0 0 1
  #|vn 0 0 -1
  #|vn 1 0 0
  #|vn -1 0 0
  #|vn 0 1 0
  #|vn 0 -1 0
  #|f 1/1/1 2/2/1 3/3/1 4/4/1
  #|f 5/1/2 6/2/2 7/3/2 8/4/2
  #|f 9/1/3 10/2/3 11/3/3 12/4/3
  #|f 13/1/4 14/2/4 15/3/4 16/4/4
  #|f 17/1/5 18/2/5 19/3/5 20/4/5
  #|f 21/1/6 22/2/6 23/3/6 24/4/6

///|
fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  // OBJ 现场解析(loaders 包)
  let report = @loaders.parse_obj_detailed(builtin_obj)
  println(
    "obj_viewer: OBJ 解析 \{report.geometry.vertex_count()} 顶点 / \{report.geometry.index_count()} 索引 / \{report.geometry.uvs.length() / 2} uv,跳过 \{report.skipped_lines} 行",
  )
  // 场景与相机
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  scene.add(
    @core.Mesh::new(
      report.geometry,
      @core.Material::basic(@math3d.Color::from_hex("#f59e0b").unwrap()),
    ),
  )
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  let controls = @controls.OrbitControls::new()
  camera.look_at(@math3d.Vector3::new(2.4, 1.8, 3.0), controls.target)
  // 窗口与容器
  let window = @yue.Window::new()
  window.set_title("three-native — obj_viewer")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // 轨道控制:yue 鼠标事件喂增量(OrbitControls 自身不监听事件)
  let dragging = Ref(false)
  let last_x = Ref(0.0)
  let last_y = Ref(0.0)
  let ev_down = Ref(0)
  let ev_move = Ref(0)
  let ev_wheel = Ref(0)
  window.on_mouse_down(fn(e) {
    ev_down.val = ev_down.val + 1
    println("EVT down #\{ev_down.val} button=\{e.button} at \{e.view_x},\{e.view_y}")
    if e.button == 1 {
      dragging.val = true
      last_x.val = e.view_x
      last_y.val = e.view_y
      window.set_capture() // 拖出控件范围也持续收到 move/up
    }
    true
  })
  window.on_mouse_move(fn(e) {
    ev_move.val = ev_move.val + 1
    if dragging.val {
      controls.rotate(
        e.view_x - last_x.val,
        e.view_y - last_y.val,
        480.0, // 视口高度:拖满一屏 = 旋转一整圈(three.js 同换算)
      )
      controls.update(camera)
      last_x.val = e.view_x
      last_y.val = e.view_y
    }
  })
  window.on_mouse_up(fn(_e) {
    dragging.val = false
    window.release_capture()
    true
  })
  window.on_capture_lost(fn() { dragging.val = false })
  // 滚轮:yue 每格 ±1,换算成 three.js 惯例的 ±100 像素 deltaY。
  // 双挂 window+host:容器事件窗口在此场景可能收不到(见 docs/research),
  // window 级实测可靠;两处不同时触发,无需防重
  fn on_wheel(delta_y : Double) -> Unit {
    ev_wheel.val = ev_wheel.val + 1
    println("EVT wheel #\{ev_wheel.val} delta=\{delta_y}")
    controls.zoom(delta_y * 100.0)
    controls.update(camera)
  }
  window.on_wheel(on_wheel)
  host.on_wheel(on_wheel)
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      println("obj_viewer: 控件未 realize")
      return
    }
    let xid = ffi_gdk_x11_window_get_xid(gdkwin)
    let xdisplay = ffi_gdk_x11_display_get_xdisplay(
      ffi_gdk_window_get_display(gdkwin),
    )
    let renderer = @renderers.WebGPURenderer::from_xlib(
      xdisplay,
      xid.to_uint64(),
      720U,
      480U,
    ) catch {
      e => {
        println("obj_viewer: 渲染器建立失败 \{e}")
        return
      }
    }
    // resize 接线:窗口尺寸变化时重配 surface 与深度,否则画面消失
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    println("obj_viewer: 渲染器就绪,左键拖拽旋转 / 滚轮缩放")
    @yue.set_timer(16, fn() {
      renderer.render(scene, camera) catch {
        e => {
          println("obj_viewer: 渲染失败 \{e}")
          return false
        }
      }
      true
    })
  })
  // 冒烟模式:15 秒后正常退出
  @yue.set_timer(15000, fn() {
    println("obj_viewer: 15s 自动退出(事件统计 down=\{ev_down.val} move=\{ev_move.val} wheel=\{ev_wheel.val})")
    @yue.quit()
    false
  })
  @yue.run()
}
