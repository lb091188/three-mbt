// input_diag:wgpu 渲染 × GTK 事件层进诊断。
// 模式经环境变量 INPUT_DIAG_MODE 控制:
//   render   持续渲染循环(基线,复现交互失效)
//   surface  只建 surface 并 configure,不渲染
//   frame    渲染 1 帧后停
// host 与 window 双通道事件计数,15s 汇总退出。

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
    println("init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let mode = match @env.get_env_var("INPUT_DIAG_MODE") {
      Some(m) => m
      None => "render"
    }
  println("input_diag mode=\{mode}")
  let window = @yue.Window::new()
  window.set_title("input-diag")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(500.0, 380.0)
  window.activate()
  let h_down = Ref(0)
  let h_wheel = Ref(0)
  let w_down = Ref(0)
  host.on_mouse_down(fn(_e) {
    h_down.val = h_down.val + 1
    println("HOST down #\{h_down.val}")
    true
  })
  host.on_wheel(fn(d) {
    h_wheel.val = h_wheel.val + 1
    println("HOST wheel #\{h_wheel.val} d=\{d}")
  })
  window.on_mouse_down(fn(_e) {
    w_down.val = w_down.val + 1
    println("WIN down #\{w_down.val}")
    true
  })
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    let xid = ffi_gdk_x11_window_get_xid(gdkwin)
    let xdisplay = ffi_gdk_x11_display_get_xdisplay(
      ffi_gdk_window_get_display(gdkwin),
    )
    if mode == "surface" {
      let _r = @renderers.WebGPURenderer::from_xlib(
        xdisplay,
        xid.to_uint64(),
        500U,
        380U,
      ) catch {
        e => {
          println("surface 建立失败 \{e}")
          return
        }
      }
      println("input_diag: surface 就绪,不渲染")
      return
    }
    let renderer = @renderers.WebGPURenderer::from_xlib(
      xdisplay,
      xid.to_uint64(),
      500U,
      380U,
    ) catch {
      e => {
        println("渲染器建立失败 \{e}")
        return
      }
    }
    let scene = @core.Scene::new()
    scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
    scene.add(
      @core.Mesh::new(
        @core.BufferGeometry::box(1.0, 1.0, 1.0),
        @core.Material::basic(@math3d.Color::from_hex("#f59e0b").unwrap()),
      ),
    )
    let camera = @core.PerspectiveCamera::new(60.0, 500.0 / 380.0, 0.1, 100.0)
    camera.look_at(@math3d.Vector3::new(2.0, 1.5, 2.5), @math3d.Vector3::zero())
    let n = Ref(0)
    @yue.set_timer(16, fn() {
      n.val = n.val + 1
      renderer.render(scene, camera) catch { _ => return false }
      if mode == "frame" && n.val >= 1 {
        println("input_diag: 已渲染 1 帧,停")
        return false
      }
      true
    })
  })
  @yue.set_timer(15000, fn() {
    println("SUMMARY mode=\{mode} host_down=\{h_down.val} host_wheel=\{h_wheel.val} win_down=\{w_down.val}")
    @yue.quit()
    false
  })
  @yue.run()
}
