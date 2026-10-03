// cube3d:three-native 首个端到端示例——yue 窗口中的旋转立方体。
// 验收:窗口出现暗色背景 + 旋转的青色立方体(深度正确、背面剔除),
// 15 秒自动退出或手动关闭,无段错误。

// GDK/X11 换算(gdk 符号在 yue 的链接闭包内)
#borrow(widget)
extern "c" fn ffi_gtk_widget_get_window(widget : UInt64) -> UInt64 = "gtk_widget_get_window"

#borrow(gdkwin)
extern "c" fn ffi_gdk_window_get_display(gdkwin : UInt64) -> UInt64 = "gdk_window_get_display"

#borrow(gdkwin)
extern "c" fn ffi_gdk_x11_window_get_xid(gdkwin : UInt64) -> UInt = "gdk_x11_window_get_xid"

#borrow(display)
extern "c" fn ffi_gdk_x11_display_get_xdisplay(display : UInt64) -> UInt64 = "gdk_x11_display_get_xdisplay"

fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("three-native — cube3d")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // 场景:旋转立方体 + 相机
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::basic(@math3d.Color::from_hex("#2dd4bf").unwrap()),
  )
  scene.add(cube)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(1.8, 1.4, 2.6),
    @math3d.Vector3::zero(),
  )
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      println("cube3d: 控件未 realize")
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
        println("cube3d: 渲染器建立失败 \{e}")
        return
      }
    }
    // resize 接线:窗口尺寸变化时重配 surface 与深度,否则画面消失
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    println("cube3d: 渲染器就绪")
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      cube.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(t * 0.9, t * 0.6, 0.0),
      )
      renderer.render(scene, camera) catch {
        e => {
          println("cube3d: 渲染失败 \{e}")
          return false
        }
      }
      true
    })
  })
  // 冒烟模式:15 秒后正常退出
  @yue.set_timer(15000, fn() {
    println("cube3d: 15s 自动退出")
    @yue.quit()
    false
  })
  @yue.run()
}
