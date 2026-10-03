// lit_cube:光照管线示例——yue 窗口中受方向光照射的两个立方体。
// 左:Lambert(无高光);右:Phong(Blinn-Phong 高光),同方向光+环境光,
// 双立方体各自自转;15 秒自动退出或手动关闭,无段错误。

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
  window.set_title("three-native — lit_cube")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // 场景:Lambert/Phong 双立方体 + 相机
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let lambert_cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::lambert(
      @math3d.Color::from_hex("#d97706").unwrap(),
      @math3d.Color::black(),
    ),
  )
  lambert_cube.position = @math3d.Vector3::new(-1.05, 0.0, 0.0)
  scene.add(lambert_cube)
  let phong_cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::phong(
      @math3d.Color::from_hex("#0ea5e9").unwrap(),
      @math3d.Color::from_hex("#9ad7f0").unwrap(),
      48.0,
      @math3d.Color::black(),
    ),
  )
  phong_cube.position = @math3d.Vector3::new(1.05, 0.0, 0.0)
  scene.add(phong_cube)
  // 光照:弱环境光 + 方向光(自右上前方照向原点)
  let ambient = @lights.AmbientLight::new(
    color=@math3d.Color::from_hex("#404040").unwrap(),
    intensity=1.0,
  )
  @renderers.attach_ambient_light(scene, ambient)
  let sun = @lights.DirectionalLight::new(intensity=3.0)
  sun.obj.position = @math3d.Vector3::new(2.5, 3.0, 1.8)
  @renderers.attach_directional_light(scene, sun)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(@math3d.Vector3::new(2.2, 1.6, 3.2), @math3d.Vector3::zero())
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      println("lit_cube: 控件未 realize")
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
        println("lit_cube: 渲染器建立失败 \{e}")
        return
      }
    }
    // resize 接线:窗口尺寸变化时重配 surface 与深度,否则画面消失
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    println("lit_cube: 渲染器就绪")
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      // 轨道式自转:绕 Y 持续旋转 + 缓慢俯仰
      lambert_cube.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(t * 0.3, t * 0.9, 0.0),
      )
      phong_cube.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(-t * 0.25, -t * 0.8, 0.0),
      )
      renderer.render(scene, camera) catch {
        e => {
          println("lit_cube: 渲染失败 \{e}")
          return false
        }
      }
      true
    })
  })
  // 冒烟模式:15 秒后正常退出
  @yue.set_timer(15000, fn() {
    println("lit_cube: 15s 自动退出")
    @yue.quit()
    false
  })
  @yue.run()
}
