// pbr_check:A3 PBR→Phong 降级验收 —— 同色木箱并排对照:
// 左 Lambert(无高光)、右 Phong(降级公式参数),方向光 + 半球光。
// 资产说明:steel-front/client/assets 129 个 GLB 已 find 过,无名字含
// crate/box/wreck/barrel 的模型(全是坦克),按预案走 BoxGeometry 兜底。
// Phong 参数按降级公式自设:metallic=1.0/roughness=0.5 →
//   specular 灰度 s = clamp(0.04+0.96*1.0) = 1.0(白),
//   shininess = clamp((1-0.5)^2*250+5) = 67.5。
// 验收:右侧箱出现明显亮于漫反射面的高光簇,左侧无;t=3s 截图,
// 300 帧(约 5s)自然退出。

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

#borrow(s, f)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

#borrow(f)
extern "c" fn c_fclose(f : UInt64) -> Int = "fclose"

extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

#borrow(path, mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///| 追加一行日志(立即落盘)
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(b"/tmp/pbr_check.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
    ignore(c_fclose(f))
  }
}

fn main raise {
  logln("---- pbr_check 启动 ----")
  if !@yue.initialize() {
    logln("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  // ---- 窗口 ----
  let window = @yue.Window::new()
  window.set_title("three-native — pbr_check")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // ---- 场景 ----
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#1a1f2b").unwrap())
  // 地面:暗色 Lambert(漫反射参照面)
  let ground = @core.Mesh::new(
    @core.BufferGeometry::plane(16.0, 16.0),
    @core.Material::lambert(
      @math3d.Color::from_hex("#262a31").unwrap(),
      @math3d.Color::black(),
    ),
  )
  ground.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(-1.5707963, 0.0, 0.0),
  )
  scene.add(ground)
  // 同色木箱并排:左 Lambert / 右 Phong(降级公式参数)
  let crate_color = @math3d.Color::from_hex("#a97c50").unwrap()
  let left = @core.Mesh::new(
    @core.BufferGeometry::box(1.8, 1.8, 1.8),
    @core.Material::lambert(crate_color, @math3d.Color::black()),
  )
  left.position = @math3d.Vector3::new(-1.6, 0.9, 0.0)
  scene.add(left)
  // Phong:metallic=1.0/roughness=0.5 → s=1.0(白高光)、shininess=67.5
  let phong_mat = @core.Material::phong(
    crate_color,
    @math3d.Color::new(1.0, 1.0, 1.0),
    67.5,
    @math3d.Color::black(),
  )
  let right = @core.Mesh::new(@core.BufferGeometry::box(1.8, 1.8, 1.8), phong_mat)
  right.position = @math3d.Vector3::new(1.6, 0.9, 0.0)
  scene.add(right)
  logln(
    "材质:左 Lambert 无高光;右 Phong specular=(1,1,1) shininess=67.5(=公式 0.04+0.96*1.0 / (1-0.5)^2*250+5)",
  )
  // 光照:方向光(相机后上方,半向量对准箱正面 → 高光可见)+
  // 半球光(天蓝/地褐,给暗面补漫反射)
  let sun = @lights.DirectionalLight::new()
  sun.intensity = 2.0
  sun.obj.position = @math3d.Vector3::new(0.0, 2.0, 9.0)
  @renderers.attach_directional_light(scene, sun)
  let hemi = @lights.HemisphereLight::new(
    sky_color=@math3d.Color::new(0.45, 0.65, 1.0),
    ground_color=@math3d.Color::new(0.45, 0.32, 0.18),
    intensity=0.6,
  )
  @renderers.attach_hemisphere_light(scene, hemi)
  let camera = @core.PerspectiveCamera::new(50.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(0.0, 1.6, 7.0),
    @math3d.Vector3::new(0.0, 0.9, 0.0),
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
      renderer.render(scene, camera) catch {
        e => {
          logln("渲染失败 \{e}")
          return false
        }
      }
      // 第 180 帧(约 3s)截图取证
      if frame.val == 180 {
        let cmd : Bytes = @utf8.encode(
            "import -window root /tmp/pbr_check.png 2>/tmp/pbr_check.err",
          ) + b"\x00"
        let rc = c_system(cmd)
        logln("截图 rc=\{rc} → /tmp/pbr_check.png(第 \{frame.val} 帧)")
      }
      // 第 300 帧(约 5s)有限帧自然退出
      if frame.val >= 300 {
        logln("300 帧完成,自然退出")
        @yue.quit()
        return false
      }
      true
    })
  })
  @yue.run()
  logln("---- pbr_check 退出 ----")
}
