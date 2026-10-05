// textured_plane:A1 纹理管线验收 —— 草地 JPG 平铺 Lambert 地面 + 无贴图
// 红盒(对照:白纹理回退路径)。
// 验收:地面呈草绿且可见纹理重复(repeat 6×6)与斜视角各向异性;
// 红盒保持纯色受光;t=4s 截图取证,15s 自动退出。

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

#borrow(path, mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

#borrow(s, f)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

#borrow(buf)
extern "c" fn c_fread(
  buf : Bytes,
  size : UInt64,
  n : UInt64,
  f : UInt64,
) -> UInt64 = "fread"

extern "c" fn c_fseek(
  f : UInt64,
  off : UInt64,
  whence : Int,
) -> Int = "fseek"

extern "c" fn c_ftell(f : UInt64) -> UInt64 = "ftell"

extern "c" fn c_fclose(f : UInt64) -> Int = "fclose"

extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///| 追加一行日志(立即落盘)
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(b"/tmp/textured_plane.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

///| 读整个文件(游戏资产在 steel-front 仓,相对路径三层返回)
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

fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  // ---- 资产:草地纹理(对齐 terrain.js:62-71 的用法)----
  let grass_bytes = read_file(
      "/home/lkyh/ownCode/steel-front/client/assets/textures/grass.jpg",
    ) catch {
    e => {
      println("读 grass.jpg 失败: \{e}")
      return
    }
  }
  let grass = @loaders.load_texture_jpeg_bytes(grass_bytes) catch {
    e => {
      println("解码 grass.jpg 失败: \{e}")
      return
    }
  }
  grass.wrap_s = @core.Wrapping::Repeat
  grass.wrap_t = @core.Wrapping::Repeat
  grass.repeat = @math3d.Vector2::new(6.0, 6.0)
  grass.anisotropy = 8
  logln(
    "grass.jpg 解码完成: \{grass.source.unwrap().width}x\{grass.source.unwrap().height}, mip \{grass.source.unwrap().mips.length()} 层",
  )
  // ---- 窗口 ----
  let window = @yue.Window::new()
  window.set_title("three-native — textured_plane")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // ---- 场景 ----
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  // 地面:20×20 Lambert 草地,平铺 6×6(水平放置 = 绕 X 转 -90°)
  let ground_mat = @core.Material::lambert(
    @math3d.Color::white(),
    @math3d.Color::black(),
  )
  ground_mat.map = Some(grass)
  let ground = @core.Mesh::new(@core.BufferGeometry::plane(20.0, 20.0), ground_mat)
  ground.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(-1.5707963, 0.0, 0.0),
  )
  scene.add(ground)
  // 对照:无贴图红盒(白纹理回退路径,应保持纯色)
  let box = @core.Mesh::new(
    @core.BufferGeometry::box(1.6, 1.6, 1.6),
    @core.Material::lambert(
      @math3d.Color::from_hex("#d64545").unwrap(),
      @math3d.Color::black(),
    ),
  )
  box.position = @math3d.Vector3::new(0.0, 1.4, 0.0)
  scene.add(box)
  // 光照:环境 + 方向(attach 进 SceneLights;太阳斜照)
  let ambient = @lights.AmbientLight::new()
  ambient.intensity = 0.45
  @renderers.attach_ambient_light(scene, ambient)
  let sun = @lights.DirectionalLight::new()
  sun.intensity = 1.1
  sun.obj.position = @math3d.Vector3::new(4.0, 8.0, 5.0)
  @renderers.attach_directional_light(scene, sun)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  // look_at(eye, target):斜俯视地面与红盒
  camera.look_at(
    @math3d.Vector3::new(0.0, 6.0, 9.0),
    @math3d.Vector3::new(0.0, 0.0, 0.0),
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
    logln("渲染器就绪")
    // 预建草地纹理,失败原因落日志(渲染内的回退路径会静默换白)
    let gt_probe = try? renderer.ensure_gpu_texture(grass)
    logln(
      match gt_probe {
        Ok(_) => "草地纹理 GPU 资源就绪"
        Err(e) => "ensure_gpu_texture 失败: \{e}"
      },
    )
    ignore(gt_probe)
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      // 红盒缓转 + 地面纹理缓慢滚动(验 UV offset 动态生效)
      box.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(0.0, t * 0.5, 0.0),
      )
      grass.offset = @math3d.Vector2::new(t * 0.02, 0.0)
      renderer.render(scene, camera) catch {
        e => {
          logln("渲染失败 \{e}")
          return false
        }
      }
      true
    })
    @yue.set_timer(4000, fn() {
      let cmd : Bytes = @utf8.encode(
          "import -window root /tmp/textured_plane.png 2>/tmp/textured_plane.err",
        ) + b"\x00"
      let rc = c_system(cmd)
      println("截图 rc=\{rc} → /tmp/textured_plane.png")
      false
    })
  })
  @yue.set_timer(15000, fn() {
    println("15s 自动退出")
    @yue.quit()
    false
  })
  @yue.run()
}
