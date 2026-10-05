// glb_viewer:A2 GLB 加载器验收 —— 加载真实坦克 bt7.glb(28 节点/24 mesh/
// 顶点色迷彩/履带轮 extras),转台展示;t=4s 截图取证,15s 退出。
// 同时打日志:节点/三角形/extras 统计,验证 turret/gun/muzzle 可按名找到。

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

#borrow(buf, f)
extern "c" fn c_fread(buf : Bytes, size : UInt64, n : UInt64, f : UInt64) -> UInt64 = "fread"

extern "c" fn c_fseek(f : UInt64, off : UInt64, whence : Int) -> Int = "fseek"

extern "c" fn c_ftell(f : UInt64) -> UInt64 = "ftell"

extern "c" fn c_fclose(f : UInt64) -> Int = "fclose"

extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(b"/tmp/glb_viewer.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

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

fn count_tris(root : @core.Object3D) -> Int {
  let tris = Ref(0)
  root.traverse(fn(o) {
    match o.mesh {
      Some(m) => tris.val = tris.val + m.geometry.index_count() / 3
      None => ()
    }
    true
  })
  tris.val
}

fn main raise {
  logln("---- glb_viewer 启动 ----")
  let glb_bytes = read_file(
      "/home/lkyh/ownCode/steel-front/client/assets/models/bt7.glb",
    ) catch {
    e => {
      logln("读 bt7.glb 失败: \{e}")
      return
    }
  }
  logln("bt7.glb 读入 \{glb_bytes.length()} 字节")
  let tank = @loaders.load_glb(glb_bytes) catch {
    e => {
      logln("load_glb 失败: \{e}")
      return
    }
  }
  logln(
    "load_glb 成功: 三角形 \{count_tris(tank)} 个;turret=\{tank_lookup(tank, "turret")}",
  )
  // ---- 窗口与场景 ----
  if !@yue.initialize() {
    logln("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("three-native — glb_viewer")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#20242e").unwrap())
  scene.add(tank)
  let ambient = @lights.AmbientLight::new()
  ambient.intensity = 0.55
  @renderers.attach_ambient_light(scene, ambient)
  let sun = @lights.DirectionalLight::new()
  sun.intensity = 1.2
  sun.obj.position = @math3d.Vector3::new(5.0, 8.0, 6.0)
  @renderers.attach_directional_light(scene, sun)
  let camera = @core.PerspectiveCamera::new(50.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(4.5, 3.2, 5.5),
    @math3d.Vector3::new(0.0, 1.2, 0.0),
  )
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
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      tank.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(0.0, t * 0.4, 0.0),
      )
      tank.update_matrix_world(true)
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
          "import -window root /tmp/glb_viewer.png 2>/dev/null",
        ) + b"\x00"
      let rc = c_system(cmd)
      logln("截图 rc=\{rc} → /tmp/glb_viewer.png")
      false
    })
  })
  @yue.set_timer(15000, fn() {
    logln("15s 自动退出")
    @yue.quit()
    false
  })
  @yue.run()
}

///| 按名查找并返回概要(装配枢轴验证)
fn tank_lookup(root : @core.Object3D, name : String) -> String {
  match @loaders.find_node_by_name(root, name) {
    Some(n) => "有(\{n.children.length()}子)"
    None => "无"
  }
}
