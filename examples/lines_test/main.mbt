// lines_test:Line 管线示例(A7)——地面网格线(LineSegments)+
// 三角形边线(Line 折线)+ 动态折线(每帧改一个端点,update_vertex
// 局部刷新顶点缓冲,顶点色渐变)。有限帧自动退出。

// GDK/X11 换算(gdk 符号在 yue 的链接闭包内)

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
/// 地面网格线端点对:XZ 平面 4m×4m、10 分格,y=0(44 顶点)
fn grid_positions() -> Array[Double] {
  let pts : Array[Double] = []
  let half = 2.0
  let step = 0.4
  let mut i = 0
  while i <= 10 {
    let c = -half + Double::from_int(i) * step
    // 平行 X 轴的一条:z=c 两端点
    pts.push(-half)
    pts.push(0.0)
    pts.push(c)
    pts.push(half)
    pts.push(0.0)
    pts.push(c)
    // 平行 Z 轴的一条:x=c 两端点
    pts.push(c)
    pts.push(0.0)
    pts.push(-half)
    pts.push(c)
    pts.push(0.0)
    pts.push(half)
    i = i + 1
  }
  pts
}

///|
/// 动态折线初始形状:X 向正弦带(48 顶点),同时生成红→青顶点色渐变
fn polyline_init(n : Int) -> (Array[Double], Array[Double]) {
  let pts : Array[Double] = []
  let cols : Array[Double] = []
  for i in 0..<n {
    let t = Double::from_int(i) / Double::from_int(n - 1)
    pts.push(-1.8 + t * 3.6)
    pts.push(0.35 + 0.18 * @math.sin(t * 6.283185307179586 * 1.5))
    pts.push(-0.6 + 1.2 * @math.cos(t * 6.283185307179586))
    // 顶点色:红(1.0,0.2,0.2)→ 青(0.2,0.9,1.0)线性插值
    cols.push(1.0 - 0.8 * t)
    cols.push(0.2 + 0.7 * t)
    cols.push(0.2 + 0.8 * t)
  }
  (pts, cols)
}

///|
fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("three-native — lines_test")
  let host = @yue.Container::new()
  host.set_background_color("#101822")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // 场景:三组线 + 相机
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  // ① 地面网格线(LineSegments / LINE_LIST)
  let grid = @core.LineSegments::from_positions(
    grid_positions(),
    @core.Material::line_basic(@math3d.Color::from_hex("#3d5266").unwrap()),
  )
  scene.add(grid)
  // ② 三角形边线(Line / LINE_STRIP,末顶点回起点闭合)
  let tri = @core.Line::from_positions(
    [-1.1, 0.9, -0.3, 1.1, 0.9, -0.3, 0.0, 0.9, 1.3, -1.1, 0.9, -0.3],
    @core.Material::line_basic(@math3d.Color::from_hex("#d97706").unwrap()),
  )
  scene.add(tri)
  // ③ 动态折线:顶点色渐变(材质 vertex_colors),每帧改末端点
  let n_poly = 48
  let (poly_pts, poly_cols) = polyline_init(n_poly)
  let poly_mat = @core.Material::line_basic(@math3d.Color::white())
  let polyline = @core.Line::from_positions(
    poly_pts,
    poly_mat,
    colors=poly_cols,
  )
  scene.add(polyline)
  let camera = @core.PerspectiveCamera::new(55.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(3.4, 2.6, 4.4),
    @math3d.Vector3::new(0.0, 0.4, 0.0),
  )
  @yue.post_task(fn() {
    let widget = @yue.native_handle_view(host.view)
    let gdkwin = ffi_gtk_widget_get_window(widget)
    if gdkwin == 0 {
      println("lines_test: 控件未 realize")
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
        println("lines_test: 渲染器建立失败 \{e}")
        return
      }
    }
    host.on_size_changed(fn() {
      let b = host.get_bounds()
      renderer.resize(b.width.to_uint(), b.height.to_uint())
    })
    println("lines_test: 渲染器就绪")
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      // 每帧只改折线末端点:端点绕圈抬落,update_vertex 12 字节局部刷新
      let last = n_poly - 1
      let ex = 1.8 + 0.15 * @math.sin(t * 2.1)
      let ey = 0.35 + 0.9 * (0.5 - 0.5 * @math.cos(t * 2.6))
      let ez = 0.6 * @math.cos(t * 1.7)
      let gpu_ok = renderer.update_vertex(polyline, last, ex, ey, ez)
      if frame.val == 5 {
        println(
          "lines_test: update_vertex 首帧GPU写入=\{gpu_ok}(首绘前 false 属预期,几何已同步)",
        )
      }
      let _ = renderer.update_vertices(polyline)
      // 三角形整体绕 Y 缓转,展示线节点走 Object3D 变换
      tri.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(0.0, t * 0.6, 0.0),
      )
      renderer.render(scene, camera) catch {
        e => {
          println("lines_test: 渲染失败 \{e}")
          return false
        }
      }
      // 有限帧退出(约 5 秒)
      if frame.val >= 300 {
        println(
          "lines_test: 300 帧自动退出,update_vertex GPU写入=\{gpu_ok}",
        )
        @yue.quit()
        return false
      }
      true
    })
  })
  @yue.run()
}
