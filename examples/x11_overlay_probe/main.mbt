// x11_overlay_probe:D1 决策的反证存档实验 —— "原生控件能不能叠在 3D 画面上方"。
// 形态:yue 窗口内 root 容器摆两个 absolute 子视图:①host(铺满,wgpu 整面
// 渲染动画渐变);②按钮(绝对定位居中,故意后加、z 序应在上面)。
// 判定:t=4s 用 ImageMagick import 截窗,若按钮可见=可叠加(推翻 D1 假设);
// 若 3D 渐变完整覆盖按钮=不可叠加(D1 全自渲染决策成立)。
// 截图落 /tmp/x11_overlay_probe.png,15s 自动退出。

#borrow(widget)
extern "c" fn ffi_gtk_widget_get_window(widget : UInt64) -> UInt64 = "gtk_widget_get_window"

#borrow(gdkwin)
extern "c" fn ffi_gdk_window_get_display(gdkwin : UInt64) -> UInt64 = "gdk_window_get_display"

#borrow(gdkwin)
extern "c" fn ffi_gdk_x11_window_get_xid(gdkwin : UInt64) -> UInt = "gdk_x11_window_get_xid"

#borrow(display)
extern "c" fn ffi_gdk_x11_display_get_xdisplay(display : UInt64) -> UInt64 = "gdk_x11_display_get_xdisplay"

#borrow(cmd)
extern "c" fn c_system(cmd : Bytes) -> Int = "system"

fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("x11-overlay-probe")
  let root = @yue.Container::new()
  // host:铺满窗口的 3D 宿主(absolute inset 0)
  let host = @yue.Container::new()
  host.set_style_str("position", "absolute")
  host.set_style_str("left", "0")
  host.set_style_str("top", "0")
  host.set_style_str("right", "0")
  host.set_style_str("bottom", "0")
  host.set_background_color("#222222")
  root.add_child(host)
  // 按钮:绝对定位盖在窗口中心(后加,yoga/z 序应在 host 之上)
  let btn = @yue.Button::new("CLICK-ME-IF-VISIBLE")
  btn.set_style_str("position", "absolute")
  btn.set_style_str("left", "260")
  btn.set_style_str("top", "210")
  btn.set_style_str("width", "200")
  btn.set_style_str("height", "60")
  let clicked = Ref(0)
  btn.on_click(fn() {
    clicked.val = clicked.val + 1
    println("按钮被点 #\{clicked.val}(说明按钮收到了事件)")
  })
  root.add_child(btn)
  window.set_content(root)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // 场景:一个铺满视锥的大盒子做"全屏 3D 内容"(Basic 材质,每帧换色形成动画)
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#1a2b4a").unwrap())
  let plane = @core.Mesh::new(
    @core.BufferGeometry::box(40.0, 40.0, 0.1),
    @core.Material::basic(@math3d.Color::from_hex("#3b82f6").unwrap()),
  )
  plane.position = @math3d.Vector3::new(0.0, 0.0, -10.0)
  scene.add(plane)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(@math3d.Vector3::new(0.0, 0.0, -10.0), @math3d.Vector3::zero())
  scene.update_matrix_world()
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      println("host 控件未 realize")
      return
    }
    let xid = ffi_gdk_x11_window_get_xid(gdkwin)
    println("host XID = 0x\{xid.to_string()}")
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
        println("渲染器建立失败 \{e}")
        return
      }
    }
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    println("渲染器就绪,开始动画")
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      // 每帧微调相机形成可见动画(证明渲染循环活着)
      let t = Int::to_double(frame.val) / 60.0
      plane.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(t * 0.2, t * 0.1, 0.0),
      )
      renderer.render(scene, camera) catch {
        e => {
          println("渲染失败 \{e}")
          return false
        }
      }
      true
    })
    // t=4s 截窗取证(等渲染稳定)
    @yue.set_timer(4000, fn() {
      let cmd : Bytes = @utf8.encode(
          "import -window root /tmp/x11_overlay_probe.png 2>/tmp/x11_overlay_probe.err",
        ) + b"\x00"
      let rc = c_system(cmd)
      println(
        "截图 rc=\{rc}(0=成功);文件 /tmp/x11_overlay_probe.png —— 打开看按钮是否可见",
      )
      false
    })
  })
  @yue.set_timer(15000, fn() {
    println("15s 自动退出;点击计数=\{clicked.val}")
    @yue.quit()
    false
  })
  @yue.run()
}
