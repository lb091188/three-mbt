// map_lightup:阶段1 里程碑示例「一张地图点亮」—— 在一个 X11 窗口里
// 合成真实地图画面:l01-encounter 16bit 高度图地形(PNG16 精确解码)+
// 草地纹理平铺(世界坐标 UV/Repeat)+ bt7.glb 坦克贴地 +
// 半球光(天淡蓝/地土黄)+ 方向光(暖白斜射)+ 线性雾(远处融进天色,
// scene.background 与雾同色)。相机绕地形中心缓慢环绕,180 帧自然退出。
// 资产均取自 steel-front 主仓(只读):client/assets/...。

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
  let f = c_fopen(b"/tmp/map_lightup.log\x00", b"a\x00")
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

///| 读整个文件(游戏资产在 steel-front 主仓,绝对路径只读)
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

///| 高程图双线性采样:像素坐标 fx/fy∈[0,res-1] → u16 值(0..65535)
fn sample_bilinear(
  px : FixedArray[Int],
  res : Int,
  fx : Double,
  fy : Double
) -> Int {
  let maxc = Double::from_int(res - 1)
  let cx = if fx < 0.0 { 0.0 } else if fx > maxc { maxc } else { fx }
  let cy = if fy < 0.0 { 0.0 } else if fy > maxc { maxc } else { fy }
  let x0 = cx.floor()
  let y0 = cy.floor()
  let x1 = if x0 >= maxc { maxc } else { x0 + 1.0 }
  let y1 = if y0 >= maxc { maxc } else { y0 + 1.0 }
  let tx = cx - x0
  let ty = cy - y0
  let xi0 = x0.to_int()
  let xi1 = x1.to_int()
  let yi0 = y0.to_int()
  let yi1 = y1.to_int()
  let v00 = px[yi0 * res + xi0]
  let v10 = px[yi0 * res + xi1]
  let v01 = px[yi1 * res + xi0]
  let v11 = px[yi1 * res + xi1]
  let top = Double::from_int(v00) * (1.0 - tx) + Double::from_int(v10) * tx
  let bot = Double::from_int(v01) * (1.0 - tx) + Double::from_int(v11) * tx
  (top * (1.0 - ty) + bot * ty).round().to_int()
}

fn main raise {
  logln("---- map_lightup 启动 ----")
  // ---- 常量:地形参数 ----
  let terrain_size = 200.0 // 世界尺寸(X/Z)
  let segs = 128 // 细分段数(顶点 129×129)
  let n = segs + 1
  let max_height = 24.0 // 高程 65535 → 24 世界单位(任务区间 18~30)
  let uv_scale = 10.0 // 草地平铺尺度:10 世界单位/纹理重复
  // ---- 高程图:PNG16 精确解码 + 对 PIL 已知值核验 ----
  let hm_bytes = read_file(
      "/home/lkyh/ownCode/steel-front/client/assets/maps/l01-encounter/heightmap.png",
    ) catch {
    e => {
      logln("读 heightmap.png 失败: \{e}")
      return
    }
  }
  let (res, res_y, pixels) = @loaders.decode_png16_gray(hm_bytes) catch {
    e => {
      logln("decode_png16_gray 失败: \{e}")
      return
    }
  }
  logln(
    "heightmap 解码: \{res}×\{res_y}, \{pixels.length()} 像素(u16), 文件 \{hm_bytes.length()} 字节",
  )
  // PIL 实测期望值(steel-front moonbit/v9_image 实验表,2026-10-05)
  let corner_checks : Array[(Int, Int, Int)] = [
    (0, 0, 60129),
    (143, 143, 6706),
    (287, 287, 60243),
  ]
  for c in corner_checks {
    let (x, y, want) = c
    let got = pixels[y * res + x]
    logln(
      "[\{if got == want { "PASS" } else { "FAIL" }}] 像素(\{x},\{y}) = \{got} 期望 \{want}",
    )
  }
  // ---- 网格高程:双线性降采样 288² → 129²,世界 Y ----
  let ys : Array[Double] = Array::make(n * n, 0.0)
  for j in 0..<n {
    for i in 0..<n {
      let fx = Double::from_int(i) / Double::from_int(segs) * Double::from_int(res - 1)
      let fy = Double::from_int(j) / Double::from_int(segs) * Double::from_int(res - 1)
      ys[j * n + i] = Double::from_int(sample_bilinear(pixels, res, fx, fy)) / 65535.0 * max_height
    }
  }
  // ---- 坦克落点:中位数高程附近(±1.5)找 5×5 窗极差最小格 ----
  let sorted = Array::new()
  for v in ys {
    sorted.push(v)
  }
  sorted.sort()
  let median = sorted[sorted.length() / 2]
  let mut best_i = -1
  let mut best_j = -1
  let mut best_spread = 1000000000.0
  let band = 44 // 中央带 ±31 世界单位,坦克离相机 119~181 而非远侧 ~190
  for j in band..<(n - band) {
    for i in band..<(n - band) {
      let y = ys[j * n + i]
      if (y - median).abs() > 1.5 {
        continue
      }
      let mut lo = 1000000000.0
      let mut hi = -1000000000.0
      for dj in -2..=2 {
        for di in -2..=2 {
          let v = ys[(j + dj) * n + (i + di)]
          if v < lo {
            lo = v
          }
          if v > hi {
            hi = v
          }
        }
      }
      let spread = hi - lo
      if spread < best_spread {
        best_spread = spread
        best_i = i
        best_j = j
      }
    }
  }
  if best_i < 0 {
    logln("没找到中位数高程附近的平缓格(不应发生)")
    return
  }
  let tank_i = best_i
  let tank_j = best_j
  let cell = terrain_size / Double::from_int(segs)
  let tank_x = -terrain_size / 2.0 + Double::from_int(tank_i) * cell
  let tank_z = -terrain_size / 2.0 + Double::from_int(tank_j) * cell
  let tank_y = ys[tank_j * n + tank_i]
  logln(
    "坦克落点: 格(\{tank_i},\{tank_j}) 世界(\{tank_x}, \{tank_y}, \{tank_z}), 中位高程 \{median}, 窗极差 \{best_spread}",
  )
  // ---- 草地纹理(Repeat 平铺,世界坐标 UV 由 heightfield 生成)----
  let grass_bytes = read_file(
      "/home/lkyh/ownCode/steel-front/client/assets/textures/grass.jpg",
    ) catch {
    e => {
      logln("读 grass.jpg 失败: \{e}")
      return
    }
  }
  let grass = @loaders.load_texture_jpeg_bytes(grass_bytes) catch {
    e => {
      logln("解码 grass.jpg 失败: \{e}")
      return
    }
  }
  grass.wrap_s = @core.Wrapping::Repeat
  grass.wrap_t = @core.Wrapping::Repeat
  grass.anisotropy = 8
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
  let tris = Ref(0)
  tank.traverse(fn(o) {
    match o.mesh {
      Some(m) => tris.val = tris.val + m.geometry.index_count() / 3
      None => ()
    }
    true
  })
  logln("bt7.glb 加载: \{tris.val} 三角形")
  // ---- 窗口 ----
  if !@yue.initialize() {
    logln("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("three-native — map_lightup")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(800.0, 600.0)
  window.activate()
  // ---- 场景:地形 + 坦克 ----
  let scene = @core.Scene::new()
  let sky_color = @math3d.Color::from_hex("#c7d4e6").unwrap() // 天/雾同色(map.json fogColor 0.78,0.83,0.9)
  scene.background = Some(sky_color)
  scene.fog = Some(
    @core.Fog::linear(
      sky_color,
      80.0,
      340.0, // 相机轨道半径 150:近缘~110 微雾、远角~312 近全雾融进天色
    ),
  )
  let terrain_geo = @core.BufferGeometry::heightfield(
    terrain_size,
    terrain_size,
    segs,
    segs,
    fn(i : Int, j : Int) { ys[j * n + i] },
    uv_scale,
  )
  logln(
    "地形网格: \{terrain_geo.vertex_count()} 顶点 / \{terrain_geo.index_count() / 3} 三角",
  )
  let terrain_mat = @core.Material::lambert(
    @math3d.Color::white(),
    @math3d.Color::black(),
  )
  terrain_mat.map = Some(grass)
  let terrain = @core.Mesh::new(terrain_geo, terrain_mat)
  scene.add(terrain)
  // 坦克贴地:×4 统一缩放(地形 200 vs 游戏世界 1000, 补偿压缩保持画面比例),朝向随意
  tank.scale = @math3d.Vector3::new(4.0, 4.0, 4.0)
  tank.position = @math3d.Vector3::new(tank_x, tank_y - 0.8, tank_z)
  tank.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(0.0, 0.8, 0.0),
  )
  scene.add(tank)
  // ---- 光照:半球(天淡蓝/地土黄)+ 方向(暖白斜射, map.json sunDir)----
  let hemi = @lights.HemisphereLight::new(
    sky_color=@math3d.Color::from_hex("#87b7e3").unwrap(),
    ground_color=@math3d.Color::from_hex("#94805c").unwrap(),
    intensity=0.7,
  )
  @renderers.attach_hemisphere_light(scene, hemi)
  let sun = @lights.DirectionalLight::new()
  sun.color = @math3d.Color::from_hex("#fff0d9").unwrap()
  sun.intensity = 1.15
  sun.obj.position = @math3d.Vector3::new(90.0, 150.0, 70.0) // 方向∝(0.45,0.75,0.35)
  @renderers.attach_directional_light(scene, sun)
  // ---- 相机:绕中心缓慢环绕(半径 150 > 对角线一半 141.4,俯角 30°)----
  let center_y = ys[(segs / 2) * n + segs / 2]
  let center = @math3d.Vector3::new(0.0, center_y, 0.0)
  let orbit_r = 150.0
  let orbit_h = orbit_r * 0.57735 // tan 30°
  let camera = @core.PerspectiveCamera::new(
    55.0,
    800.0 / 600.0,
    1.0,
    800.0,
  )
  camera.look_at(
    @math3d.Vector3::new(orbit_r, center_y + orbit_h, 0.0),
    center,
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
    logln("渲染器就绪, 开始环绕")
    let frame = Ref(0)
    let total_frames = 180
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let a = Double::from_int(frame.val) * 0.004 // 每帧 0.229°,全程 ~41°
      camera.look_at(
        @math3d.Vector3::new(
          center.x + orbit_r * @math.cos(a),
          center_y + orbit_h,
          center.z + orbit_r * @math.sin(a),
        ),
        center,
      )
      scene.update_matrix_world()
      renderer.render(scene, camera) catch {
        e => {
          logln("渲染失败 \{e}")
          return false
        }
      }
      if frame.val == 160 {
        let cmd : Bytes = @utf8.encode(
            "import -window root /tmp/map_lightup.png 2>/tmp/map_lightup.err",
          ) + b"\x00"
        let rc = c_system(cmd)
        logln("截图 rc=\{rc} → /tmp/map_lightup.png")
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
