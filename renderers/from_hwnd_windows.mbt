// from_hwnd:Win32 专属构造器(与 renderer.mbt 的 from_xlib 对位)。
// 独立成文件 + #cfg(platform="windows"):GetModuleHandleW 仅 Windows 存在,
// 非 Windows 走 from_hwnd_other.mbt 占位,Linux/macOS 的编译链接保持绿。

///| Win32:进程默认 HINSTANCE(GetModuleHandleW(NULL),kernel32 默认链接)。
///| 传 0 即 NULL 模块名 → 当前可执行映像基址,与 yue 建窗所用一致。
#cfg(platform="windows")
extern "c" fn win32_process_hinstance(module_name : UInt64) -> UInt64 = "GetModuleHandleW"

///| 从 Win32 顶层窗口 HWND 创建渲染器(整窗渲染;Win10 19045 真机趟通)。
///| hinstance 由内部取进程默认(GetModuleHandleW(NULL));adapter 优先
///| 强制 D3D12(Windows 原生预期路径),拿不到再回退默认枚举(Vulkan 等)。
#cfg(platform="windows")
pub fn WebGPURenderer::from_hwnd(
  hwnd : UInt64,
  width : UInt,
  height : UInt,
) -> WebGPURenderer raise Error {
  @wgpu_mbt.set_uncaptured_error_stderr_enabled(true)
  @wgpu_mbt.set_log_callback_stderr_enabled(true)
  let instance = @wgpu_mbt.Instance::create()
  let hinstance = win32_process_hinstance(0)
  let surface = instance.create_surface_windows_hwnd(
    @c.opaque_ptr_from_u64(hinstance),
    @c.opaque_ptr_from_u64(hwnd),
  )
  // surface 优先 D3D12;驱动不给就默认枚举(核显机器可能报 Vulkan)
  let adapter = try {
    instance.request_adapter_sync_options_surface_u32(
      surface,
      backend_type_u32=@wgpu_mbt.BACKEND_TYPE_D3_D12,
    )
  } catch {
    _ => instance.request_adapter_sync_options_surface_u32(surface)
  }
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let format = surface.configure_default(
    adapter,
    device,
    width,
    height,
    @wgpu_mbt.TextureUsage::from_u64(
      @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
    ),
  )
  let bglb = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=1UL)
  let _bgl_ok = bglb.add_buffer(
    0U,
    @wgpu_mbt.ShaderStage::from_u64(
      @wgpu_mbt.SHADER_STAGE_VERTEX |
      @wgpu_mbt.SHADER_STAGE_FRAGMENT,
    ),
    @wgpu_mbt.BUFFER_BINDING_TYPE_UNIFORM,
  )
  let bgl = bglb.finish(device)
  let pipeline = create_basic_pipeline(device, format, bgl)
  let lit_pipeline = create_lit_pipeline(device, format, bgl)
  let r : WebGPURenderer = {
    instance,
    adapter,
    device,
    queue,
    surface,
    format,
    pipeline_basic: pipeline,
    pipeline_lit: lit_pipeline,
    bgl,
    width,
    height,
    depth_view: None,
    mesh_cache: @hashmap.HashMap([], capacity=64),
    warned_acquire: false,
  }
  r.rebuild_depth()
  r
}
