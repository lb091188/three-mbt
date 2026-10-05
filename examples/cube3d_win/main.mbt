// cube3d_win:cube3d 的 Windows 版端到端——yue 窗口整窗 HWND →
// wgpu_mbt D3D12 surface → Phong 姿态旋转立方体(与 cube3d 同场景)。
// 兼具 V5 验证:渲染循环运行中对整窗挂 on_mouse_down / on_wheel 计数,
// 15 秒自动退出时汇报;resize 接线走 Window.on_size_changed。
// 窗口定位:FindWindowA 按纯 ASCII 标题找自身顶层 HWND(不依赖
// libyue 0.5.10 之后新增的 native_handle_window,注册版包即可跑)。

///| Win32:按窗口标题找顶层窗口(ANSI 版;标题须纯 ASCII,参数带 NUL)
#borrow(title)
extern "c" fn win32_find_window_a(cls : UInt64, title : Bytes) -> UInt64 = "FindWindowA"

// 直接文件日志(fopen/fputs/fflush):moon 原生 stdout 在重定向下全缓冲,
// 崩溃即丢;证据链(V4/V5)与崩溃定位都要每行落盘。
#borrow(path, mode)
extern "c" fn c_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

#borrow(s)
extern "c" fn c_fputs(s : Bytes, f : UInt64) -> Int = "fputs"

extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

///| 追加一行日志到 cube3d_win.log(工作目录),立即落盘
fn logln(s : String) -> Unit {
  let line : Bytes = @utf8.encode(s) + b"\n\x00"
  let f = c_fopen(
    b"cube3d_win.log\x00",
    b"a\x00",
  )
  if f != 0 {
    ignore(c_fputs(line, f))
    ignore(c_fflush(f))
  }
}

fn main raise {
  if !@yue.initialize() {
    logln("cube3d_win: yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("cube3dwin")
  let host = @yue.Container::new()
  host.set_background_color("#222222")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  // V5:渲染运行期间的输入事件计数(挂 Window 级)
  let clicks = Ref(0)
  let wheels = Ref(0)
  // 输入全挂 host 容器(游戏 3D 载体即整窗容器):Window 在 Windows 的
  // on_wheel 走 CastToView 错位强转(Linux 同族 bug 已按类名分派修过,
  // wheel_hook 是 ViewImpl 内部件)→ 挂 Window 收不到滚轮;
  // Container 是真 View,wheel_hook/鼠标信号全正常。
  host.on_mouse_down(fn(_e) {
    clicks.val = clicks.val + 1
    logln("cube3d_win: mouse_down #\{clicks.val}")
    false
  })
  host.on_wheel(fn(_d) {
    wheels.val = wheels.val + 1
    logln("cube3d_win: wheel #\{wheels.val}")
  })
  // 场景:旋转立方体 + 相机(与 cube3d 一致)
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::basic(@math3d.Color::from_hex("#2dd4bf").unwrap()),
  )
  scene.add(cube)
  let camera = @core.PerspectiveCamera::new(60.0, 720.0 / 480.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(1.8, 1.4, 2.6),
    @math3d.Vector3::zero(),
  )
  @yue.post_task(fn() {
    let hwnd = win32_find_window_a(0, b"cube3dwin\x00")
    logln("cube3d_win: hwnd=\{hwnd}")
    if hwnd == 0 {
      logln("cube3d_win: FindWindowA 未找到窗口")
      return
    }
    let renderer = @renderers.WebGPURenderer::from_hwnd(hwnd, 720U, 480U) catch {
      e => {
        logln("cube3d_win: 渲染器建立失败 \{e}")
        return
      }
    }
    let backend = renderer.adapter.info_backend_type_u32()
    logln(
      "cube3d_win: 渲染器就绪 backend=\{backend}(4=D3D12 6=Vulkan) vendor=\{renderer.adapter.info_vendor()}",
    )
    // resize:整窗渲染跟随内容区尺寸重配 surface 与深度。
    // ⚠ Windows 关键时序:D3D12 下不得在 WM_SIZE 同步栈内 reconfigure
    // (最大化进行中 swapchain 仍被占用 → ResizeBuffers 无效调用/
    // Configure "window is in use" → wgpu-native Rust panic 直接 abort,
    // MoonBit catch 接不住)。post_task 延出窗口过程,pending 期跳帧。
    let resize_pending = Ref(false)
    window.on_size_changed(fn() {
      resize_pending.val = true
      @yue.post_task(fn() {
        if resize_pending.val {
          resize_pending.val = false
          let s = window.get_content_size()
          renderer.resize(s.width.to_uint(), s.height.to_uint())
          logln("cube3d_win: resize -> \{s.width}x\{s.height}")
        }
      })
    })
    logln("cube3d_win: 渲染循环启动")
    let frame = Ref(0)
    @yue.set_timer(16, fn() {
      if resize_pending.val {
        return true
      }
      frame.val = frame.val + 1
      let t = Int::to_double(frame.val) / 60.0
      cube.rotation = @math3d.Quaternion::from_euler(
        @math3d.Euler::new(t * 0.9, t * 0.6, 0.0),
      )
      renderer.render(scene, camera) catch {
        e => {
          logln("cube3d_win: 渲染失败 \{e}")
          return false
        }
      }
      true
    })
  })
  // 冒烟模式:15 秒后正常退出并汇报 V5 计数
  @yue.set_timer(15000, fn() {
    logln(
      "cube3d_win: 15s 自动退出 clicks=\{clicks.val} wheels=\{wheels.val}",
    )
    @yue.quit()
    false
  })
  @yue.run()
}
