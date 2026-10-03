// window_host:three-native 宿主无关性验证——窗口宿主是 wzzc-dev/window
// (winit 风格,与 yue/GTK 完全无关的独立窗口栈),渲染走同一套
// WebGPURenderer。证明库只依赖"原生句柄+帧驱动+resize"三个宿主接口。
// Phong 立方体 + 方向光,15 秒自动退出。

struct App {
  // 冒烟模式开关(WINDOW_HOST_AUTOEXIT=1 时 15 秒自动退出,默认常驻关窗退)
  autoexit : Bool
  mut window : @linux.Window?
  mut renderer : @renderers.WebGPURenderer?
  scene : @core.Scene
  cube : @core.Object3D
  camera : @core.PerspectiveCamera
  mut frame : Int
}

pub impl @linux.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let attrs = @win_core.WindowAttributes::default()
    .with_title("three-native × wzzc-dev/window — Phong cube")
    .with_surface_size(@dpi.PhysicalSize::PhysicalSize(720, 480).into_size())
  let linux_attrs = @linux.WindowAttributesLinux::default().with_app_id(
    "NoahLiu.three-native.window-host",
  )
  let window = event_loop.create_window_with_linux_attributes(
    attrs,
    linux_attrs,
  )
  self.window = Some(window)
  // 宿主接入协议第 1 条:原生句柄(X11 Display* + XID)
  let display = event_loop.native_display_handle()
  let xid = window.native_window_handle()
  println("window_host: display=\{display} xid=\{xid}")
  self.renderer = Some(
    @renderers.WebGPURenderer::from_xlib(display, xid, 720U, 480U) catch {
      err => {
        println("window_host: 渲染器建立失败 \{err}")
        event_loop.exit()
        return
      }
    },
  )
  println("window_host: 渲染器就绪")
  window.request_redraw()
}

pub impl @linux.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    CloseRequested => event_loop.exit()
    // 宿主接入协议第 3 条:resize 通知
    SurfaceResized(size) =>
      match self.renderer {
        Some(r) => r.resize(Int::reinterpret_as_uint(size.width), Int::reinterpret_as_uint(size.height))
        None => ()
      }
    // 宿主接入协议第 2 条:帧驱动(RedrawRequested 内渲染再请求下一帧)
    RedrawRequested => {
      self.frame = self.frame + 1
      match (self.renderer, self.window) {
        (Some(r), Some(w)) => {
          let t = Int::to_double(self.frame) / 60.0
          self.cube.rotation = @math3d.Quaternion::from_euler(
            @math3d.Euler::new(t * 0.9, t * 0.6, 0.0),
          )
          r.render(self.scene, self.camera) catch {
            e => {
              println("window_host: 渲染失败 \{e}")
              event_loop.exit()
              return
            }
          }
          if self.autoexit && self.frame >= 900 {
            println("window_host: 900 帧完成自动退出")
            event_loop.exit()
            return
          }
          w.request_redraw()
        }
        _ => ()
      }
    }
    _ => ()
  }
}

fn main raise {
  @wgpu_mbt.require_native()
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::phong(
      @math3d.Color::from_hex("#38bdf8").unwrap(),
      @math3d.Color::from_hex("#ffffff").unwrap(),
      48.0,
      @math3d.Color::from_hex("#000000").unwrap(),
    ),
  )
  scene.add(cube)
  let ambient = @lights.AmbientLight::new(color=@math3d.Color::from_hex("#404040").unwrap(), intensity=1.0)
  @renderers.attach_ambient_light(scene, ambient)
  let sun = @lights.DirectionalLight::new(intensity=3.0)
  sun.obj.position = @math3d.Vector3::new(2.5, 3.0, 1.8)
  @renderers.attach_directional_light(scene, sun)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(@math3d.Vector3::new(2.2, 1.6, 3.2), @math3d.Vector3::zero())
  let event_loop = @linux.EventLoop::new()
  let autoexit = match @env.get_env_var("WINDOW_HOST_AUTOEXIT") {
    Some(v) => v == "1"
    None => false
  }
  event_loop.run_app({
    autoexit,
    window: None,
    renderer: None,
    scene,
    cube,
    camera,
    frame: 0,
  })
}
