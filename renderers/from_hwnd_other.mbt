// from_hwnd 的非 Windows 占位:Win32 符号(GetModuleHandleW 等)在
// Linux/macOS 不存在,门控到 from_hwnd_windows.mbt;此处保持包在非
// Windows 平台可编译可链接,调用即明确报错并指路对应构造器。

#cfg(not(platform="windows"))
pub fn WebGPURenderer::from_hwnd(
  _hwnd : UInt64,
  _width : UInt,
  _height : UInt,
) -> WebGPURenderer raise Error {
  raise Failure(
    "from_hwnd 仅 Windows(HWND + D3D12);Linux 用 from_xlib,macOS 路径待铺",
  )
}
