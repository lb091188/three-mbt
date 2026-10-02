// yue×wgpu 整合 spike:X11 窗口化 surface 全链路验证。
// 验收:窗口区域被 wgpu clear 色覆盖且随时间变色(present/acquire 成功),
// 关闭窗口退出无崩溃;控制台打印各环节句柄与返回码。

// GDK/X11 换算(gdk 符号在 yue 的链接闭包内,零额外链接配置)
#borrow(widget)
extern "c" fn ffi_gtk_widget_get_window(widget : UInt64) -> UInt64 = "gtk_widget_get_window"

#borrow(gdkwin)
extern "c" fn ffi_gdk_window_get_display(gdkwin : UInt64) -> UInt64 = "gdk_window_get_display"

#borrow(gdkwin)
extern "c" fn ffi_gdk_x11_window_get_xid(gdkwin : UInt64) -> UInt = "gdk_x11_window_get_xid"

#borrow(display)
extern "c" fn ffi_gdk_x11_display_get_xdisplay(display : UInt64) -> UInt64 = "gdk_x11_display_get_xdisplay"

/// 建立 X11 surface 并启动帧循环(失败时打印环节并中止)
fn start_surface(
  host : @yue.Container,
  instance : @wgpu_mbt.Instance,
) -> Unit raise Error {
  let widget = @yue.native_handle_view(host.view)
  let gdkwin = ffi_gtk_widget_get_window(widget)
  if gdkwin == 0 {
    println("spike: 控件未 realize(无 GdkWindow)")
    return
  }
  let xid = ffi_gdk_x11_window_get_xid(gdkwin)
  let xdisplay = ffi_gdk_x11_display_get_xdisplay(
    ffi_gdk_window_get_display(gdkwin),
  )
  println("spike: widget=\{widget} gdkwin=\{gdkwin} xid=\{xid}")
  let surface = instance.create_surface_xlib(
    @c.opaque_ptr_from_u64(xdisplay),
    xid.to_uint64(),
  )
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  // surface 尺寸必须与窗口实际分配一致,否则 acquire 返回 Outdated(status=4)
  let b = host.get_bounds()
  let w = if b.width > 1.0 { b.width.to_uint() } else { 800 }
  let h = if b.height > 1.0 { b.height.to_uint() } else { 600 }
  let configured = surface.configure_best_effort(
    adapter,
    device,
    w,
    h,
    @wgpu_mbt.TextureUsage::from_u64(
      @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
    ),
  )
  println("spike: size=\{w}x\{h} configure_best_effort=\{configured}")
  if !configured {
    surface.release()
    return
  }
  let frame = Ref(0)
  @yue.set_timer(16, fn() {
    frame.val = frame.val + 1
    // 锯齿波三通道循环变色,验证持续 present
    let t = Float::from_int(frame.val % 180) / 180.0
    let r = t
    let g = if t + 0.33 > 1.0 { t - 0.67 } else { t + 0.33 }
    let b = if t + 0.67 > 1.0 { t - 0.33 } else { t + 0.67 }
    let st = surface.get_current_texture()
    if !st.is_success() {
      println("spike: acquire 失败 status=\{st.status()}")
      st.release()
      return false
    }
    let tex = st.take_texture()
    let view = tex.create_view()
    let encoder = device.create_command_encoder()
    let pass = encoder.begin_render_pass_color_clear(view, r, g, b, 1.0)
    pass.end()
    queue.submit_one(encoder.finish())
    let present_status = surface.present()
    if frame.val == 1 {
      println("spike: 首帧 present status=\{present_status}")
    }
    true
  })
}

fn main raise {
  if !@yue.initialize() {
    println("yue init 失败")
    return
  }
  @wgpu_mbt.require_native()
  let window = @yue.Window::new()
  window.set_title("yue × wgpu — X11 surface spike")
  let host = @yue.Container::new()
  host.set_background_color("#444444")
  window.set_content(host)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(720.0, 480.0)
  window.activate()
  let instance = @wgpu_mbt.Instance::create()
  @yue.post_task(fn() {
    start_surface(host, instance) catch {
      e => println("spike: 建立失败 \{e}")
    }
  })
  // 冒烟模式:15 秒后走正常退出路径(验证退出行为并 flush 日志)
  @yue.set_timer(15000, fn() {
    println("spike: 15s 自动退出")
    @yue.quit()
    false
  })
  @yue.run()
  instance.release()
}
