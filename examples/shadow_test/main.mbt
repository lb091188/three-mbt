// shadow_test:A5 方向光阴影验收 —— 地面平面 + 三个箱子 + bt7.glb 坦克,
// 半球光(天淡蓝/地土黄)+ 方向光(暖白斜射,cast_shadow,map_size 1024,
// 正交视锥 ±28)。坦克缓慢自转(阴影随之扫过地面),240 帧自然退出,
// 第 190 帧截图取证(存 /tmp/shadow_test.png)。

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
#borrow(cmd)
extern "c" fn c_system(cmd : Bytes) -> Int = "system"

///|
#borrow(path, mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///|
#borrow(s, f)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

///|
#borrow(buf, f)
extern "c" fn c_fread(
  buf : Bytes,
  size : UInt64,
  n : UInt64,
  f : UInt64,
) -> UInt64 = "fread"

///|
extern "c" fn c_fseek(f : UInt64, off : UInt64, whence : Int) -> Int = "fseek"

///|
extern "c" fn c_ftell(f : UInt64) -> UInt64 = "ftell"

///|
extern "c" fn c_fclose(f : UInt64) -> Int = "fclose"

///|
extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///|
/// 追加一行日志(立即落盘)
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(b"/tmp/shadow_test.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

///|
/// 读整个文件(游戏资产在 steel-front 主仓,绝对路径只读)
fn read_file(path : String) -> Bytes raise Error {
  let p : Bytes = @utf8.encode(path) + b"\x00"
  let f = c_fopen(p, b"rb\x00")
  if f == 0 {
    raise Failure("打不开 \{path}")
  }
  ignore(c_fseek(f, 0UL, 2))
  let len = c_ftell(f).reinterpret_as_int64().to_int()
  ignore(c_fseek(f, 0UL, 0))
  let buf = Bytes::makei(len, _ => b'\x00')
  let got = c_fread(buf, 1UL, len.to_uint64(), f)
  ignore(c_fclose(f))
  if got.reinterpret_as_int64().to_int() != len {
    raise Failure("读不完整 \{path}")
  }
  buf
}

///|
/// 立一个箱子(lambert,位置为箱底中心)
fn add_box(
  scene : @core.Scene,
  w : Double,
  h : Double,
  d : Double,
  x : Double,
  z : Double,
  yaw : Double,
  color : @math3d.Color,
) -> @core.Object3D {
  let mat = @core.Material::lambert(color, @math3d.Color::black())
  let box = @core.Mesh::new(@core.BufferGeometry::box(w, h, d), mat)
  box.position = @math3d.Vector3::new(x, h / 2.0, z)
  box.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(0.0, yaw, 0.0),
  )
  scene.add(box)
  box
}

///|
fn main raise {
  logln("---- shadow_test 启动 ----")
  // ---- 坦克:bt7.glb(同 glb_viewer)----
  let glb_bytes = read_file(
    "/home/lkyh/ownCode/steel-front/client/assets/models/bt7.glb",
  ) catch {
    e => {
      logln("读 bt7.glb 失败: \{e}")
      return
    }
  }
  let tank = @loaders.load_glb(glb_bytes) catch {
    e => {
      logln("load_glb 失败: \{e}")
      return
    }
  }
  logln("bt7.glb 加载成功")
  // ---- 窗口 ----
  if !@yue.initialize() {
    logln("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("three-native — shadow_test")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(800.0, 600.0)
  window.activate()
  // ---- 场景:地面 + 箱子 + 坦克 ----
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#20242e").unwrap())
  // 地面:60×60 平面,-90° 绕 x 躺平(three.js 同式),草绿 lambert
  let ground_mat = @core.Material::lambert(
    @math3d.Color::from_hex("#6f8752").unwrap(),
    @math3d.Color::black(),
  )
  let ground = @core.Mesh::new(
    @core.BufferGeometry::plane(60.0, 60.0),
    ground_mat,
  )
  ground.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(-3.141592653589793 / 2.0, 0.0, 0.0),
  )
  scene.add(ground)
  // 三个箱子:不同尺寸/朝向/位置(投影源)
  let _b1 = add_box(
    scene,
    4.0,
    4.0,
    4.0,
    -9.0,
    -4.0,
    0.3,
    @math3d.Color::from_hex("#b06a4a").unwrap(),
  )
  let _b2 = add_box(
    scene,
    7.0,
    2.6,
    2.4,
    8.0,
    3.0,
    -0.5,
    @math3d.Color::from_hex("#8a8f98").unwrap(),
  )
  let _b3 = add_box(
    scene,
    2.6,
    6.0,
    2.6,
    1.5,
    -10.0,
    0.9,
    @math3d.Color::from_hex("#c9a55c").unwrap(),
  )
  // 坦克:×2.5 缩放放原点附近,slow spin 中阴影贴地扫过
  tank.scale = @math3d.Vector3::new(2.5, 2.5, 2.5)
  tank.position = @math3d.Vector3::new(-1.0, 0.0, 6.0)
  scene.add(tank)
  // ---- 光照:半球 + 方向光(开阴影)----
  let hemi = @lights.HemisphereLight::new(
    sky_color=@math3d.Color::from_hex("#87b7e3").unwrap(),
    ground_color=@math3d.Color::from_hex("#94805c").unwrap(),
    intensity=0.55,
  )
  @renderers.attach_hemisphere_light(scene, hemi)
  let sun = @lights.DirectionalLight::new()
  sun.color = @math3d.Color::from_hex("#fff0d9").unwrap()
  sun.intensity = 1.25
  sun.obj.position = @math3d.Vector3::new(30.0, 42.0, 18.0)
  sun.cast_shadow = true
  sun.shadow.map_size = 1024
  sun.shadow.bias = 0.0015
  sun.shadow.camera.left = -28.0
  sun.shadow.camera.right = 28.0
  sun.shadow.camera.top = 28.0
  sun.shadow.camera.bottom = -28.0
  sun.shadow.camera.near = 1.0
  sun.shadow.camera.far = 120.0
  @renderers.attach_directional_light(scene, sun)
  logln(
    "方向光挂接: cast_shadow=\{scene.lights.directional.unwrap().cast_shadow} map=\{sun.shadow.map_size}",
  )
  // ---- 相机:东南上方向看原点(能看到箱影与坦克)----
  let camera = @core.PerspectiveCamera::new(50.0, 800.0 / 600.0, 0.1, 300.0)
  camera.look_at(
    @math3d.Vector3::new(23.0, 17.0, 27.0),
    @math3d.Vector3::new(0.0, 2.0, 0.0),
  )
  scene.update_matrix_world()
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    let xid = ffi_gdk_x11_window_get_xid(gdkwin)
    let xdisplay = ffi_gdk_x11_display_get_xdisplay(
      ffi_gdk_window_get_display(gdkwin),
    )
    let renderer = @renderers.WebGPURenderer::from_xlib(
      xdisplay,
      xid.to_uint64(),
      800U,
      600U,
    ) catch {
      e => {
        logln("渲染器建立失败 \{e}")
        return
      }
    }
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    logln("渲染器就绪")
    let frame = Ref(0)
    let total_frames = 240
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      // 坦克缓慢自转(0.25 rad/s)
      tank.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(0.0, t * 0.25, 0.0),
      )
      tank.update_matrix_world(true)
      renderer.render(scene, camera) catch {
        e => {
          logln("渲染失败 \{e}")
          return false
        }
      }
      if frame.val == 190 {
        let cmd : Bytes = @utf8.encode(
            "import -window root /tmp/shadow_test_raw.png 2>/tmp/shadow_test.err",
          ) +
          b"\x00"
        let rc = c_system(cmd)
        logln("截图 rc=\{rc} → /tmp/shadow_test_raw.png")
      }
      if frame.val >= total_frames {
        logln("\{total_frames} 帧跑满, 自然退出")
        @yue.quit()
        return false
      }
      true
    })
  })
  @yue.run()
  logln("退出")
}
