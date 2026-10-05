// sprite_test:A8 公告板精灵 + 最简粒子系统验收。
// 场景:不透明灰盒(深度/混合参照)+ 程序生成软圆盘纹理的精灵(左)+
// 200 粒子池的喷泉(右)。相机缓慢环绕 —— 精灵/粒子四边形始终面向相机。
// 验收:精灵与粒子在任意相机方位都以全正面朝向相机(无侧棱)、
// alpha 混合正确叠在灰盒上、喷泉粒子受重力上升回落、死亡粒子退化折叠;
// 第 120 帧截图取证,第 240 帧自动退出(有限帧)。

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
extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///|
/// 追加一行日志(立即落盘)
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(b"/tmp/sprite_test.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

///| 程序化软圆盘纹理(64×64 RGBA:白核 + 平滑 alpha 衰减到透明边)。

///|
/// 精灵与粒子共用;免外部资产,示例自包含。
fn make_disc_texture() -> @core.Texture {
  let size = 64
  let pixels : FixedArray[Byte] = FixedArray::make(size * size * 4, b'\x00')
  let half = Int::to_double(size) / 2.0
  for y in 0..<size {
    for x in 0..<size {
      let dx = (Int::to_double(x) + 0.5 - half) / half
      let dy = (Int::to_double(y) + 0.5 - half) / half
      let r = (dx * dx + dy * dy).sqrt()
      // r=0 中心 → alpha 1;r≥1 出界 → 0;0.55 后线性衰减(软边)
      let a = if r >= 1.0 {
        0.0
      } else if r <= 0.55 {
        1.0
      } else {
        1.0 - (r - 0.55) / 0.45
      }
      // 中心提亮(火光核心感):rgb = 1 → 0.75 随半径回落
      let core = 1.0 - r * 0.25
      let i = (y * size + x) * 4
      pixels[i] = (core * 255.0).to_int().to_byte()
      pixels[i + 1] = (core * 255.0).to_int().to_byte()
      pixels[i + 2] = (core * 255.0).to_int().to_byte()
      pixels[i + 3] = (a * 255.0).to_int().to_byte()
    }
  }
  @core.Texture::from_rgba(size, size, Bytes::from_array(pixels[:]))
}

///|
/// 确定性 LCG 随机数(喷泉喷射参数;免随机库依赖,逐次可复现)
struct Rng {
  mut state : UInt64
}

///|
fn Rng::next_unit(self : Rng) -> Double {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  let bits = (self.state >> 33) & 0xFFFFFFUL
  Int::to_double(bits.reinterpret_as_int64().to_int()) / 16777216.0
}

///|
fn Rng::range(self : Rng, lo : Double, hi : Double) -> Double {
  lo + self.next_unit() * (hi - lo)
}

///|
fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  // ---- 纹理:程序软圆盘 ----
  let disc = make_disc_texture()
  // ---- 窗口 ----
  let window = @yue.Window::new()
  window.set_title("three-native — sprite_test")
  let host = @yue.Container::new()
  host.set_background_color("#101018")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // ---- 场景 ----
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#0a0e16").unwrap())
  // 不透明灰盒:混合与深度参照(精灵/粒子叠在其上应半透、被其遮挡面正确)
  let box_node = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::lambert(
      @math3d.Color::from_hex("#6a7078").unwrap(),
      @math3d.Color::black(),
    ),
  )
  box_node.position = @math3d.Vector3::new(0.0, 0.6, -1.6)
  scene.add(box_node)
  // 光照:只服务灰盒(公告板材质不参与光照)
  let ambient = @lights.AmbientLight::new()
  ambient.intensity = 0.5
  @renderers.attach_ambient_light(scene, ambient)
  let sun = @lights.DirectionalLight::new()
  sun.intensity = 1.0
  sun.obj.position = @math3d.Vector3::new(3.0, 6.0, 4.0)
  @renderers.attach_directional_light(scene, sun)
  // 精灵:软圆盘纹理 + 暖色 + 屏面内旋转 0.7rad(验 GPU 侧 rotation)
  let sprite_mat = @core.Material::sprite(@math3d.Color::new(1.0, 0.82, 0.45))
  sprite_mat.map = Some(disc)
  sprite_mat.opacity = 0.95
  sprite_mat.rotation = 0.7
  let sprite_node = @core.Mesh::new(
    @core.BufferGeometry::sprite_quad(),
    sprite_mat,
  )
  sprite_node.position = @math3d.Vector3::new(-1.9, 1.5, 0.0)
  sprite_node.scale = @math3d.Vector3::new(2.2, 2.2, 1.0)
  scene.add(sprite_node)
  // 粒子喷泉:200 池,蓝白水珠,重力回落
  let particle_mat = @core.Material::particle(
    @math3d.Color::new(0.55, 0.75, 1.0),
  )
  particle_mat.map = Some(disc)
  particle_mat.opacity = 0.85
  let fountain = @core.ParticleSystem::new(200, particle_mat)
  fountain.gravity = -6.0
  scene.add(fountain.obj)
  // 相机:环绕原点,验公告板任意方位全正面
  let camera = @core.PerspectiveCamera::new(55.0, 720.0 / 480.0, 0.1, 100.0)
  let rng = Rng::{ state: 20261006UL, }
  // 开局先喷一批,避免前几秒空场
  for _i in 0..<40 {
    let _ = fountain.spawn(
      1.6,
      0.2,
      0.0,
      rng.range(-0.9, 0.9),
      rng.range(2.4, 4.2),
      rng.range(-0.9, 0.9),
      rng.range(1.2, 1.8),
      rng.range(0.12, 0.3),
    )
  }
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
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      // 相机绕场景缓慢公转(公告板朝向验真的关键:非面向相机的
      // 静止四边形此刻会呈现侧棱)
      let ang = t * 0.25
      let eye = @math3d.Vector3::new(
        0.3 + 5.5 * @math.cos(ang),
        1.7,
        5.5 * @math.sin(ang),
      )
      camera.look_at(eye, @math3d.Vector3::new(0.1, 0.9, 0.0))
      // 粒子步进:公告板轴取自当前相机,物理 + 动态几何一次完成
      let (right, up) = @core.billboard_axes_of(camera)
      fountain.step(1.0 / 60.0, right, up)
      // 持续补喷(池内 <200 时每帧 2 颗,稳态约 170~200 活跃)
      if fountain.alive_count() < 200 {
        for _i in 0..<2 {
          let _ = fountain.spawn(
            1.6,
            0.2,
            0.0,
            rng.range(-0.9, 0.9),
            rng.range(2.4, 4.2),
            rng.range(-0.9, 0.9),
            rng.range(1.2, 1.8),
            rng.range(0.12, 0.3),
          )
        }
      }
      renderer.render(scene, camera) catch {
        e => {
          logln("渲染失败 \{e}")
          return false
        }
      }
      if frame.val == 30 || frame.val == 180 || frame.val == 239 {
        logln("frame=\{frame.val} alive=\{fountain.alive_count()} t=\{t}")
      }
      // 两帧取证:相机方位角相差 37°(0.25rad/s × 150 帧),公告板在
      // 两个方位都应呈全正面圆盘 —— 面向相机的直接视觉证据
      if frame.val == 30 || frame.val == 180 {
        let cmd : Bytes = @utf8.encode(
            "import -window root /tmp/sprite_test_f\{frame.val}.png 2>/tmp/sprite_test.err",
          ) +
          b"\x00"
        let rc = c_system(cmd)
        logln("截图 rc=\{rc} → /tmp/sprite_test_f\{frame.val}.png")
      }
      if frame.val >= 240 {
        logln("240 帧到,自动退出")
        @yue.quit()
        return false
      }
      true
    })
  })
  @yue.run()
}
