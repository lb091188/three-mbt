// cube3d_win 的非 Windows 占位 main:真实实现(FindWindowA + from_hwnd +
// D3D12)在 main.mbt 内 #cfg(platform="windows") 门控 —— Win32 符号在
// Linux/macOS 不存在,占位保包可编译可链接,跑起来明确告知去向。

#cfg(not(platform="windows"))
fn main {
  println("cube3d_win: Windows 专用示例(HWND → D3D12);Linux 请跑 examples/cube3d(X11)")
}
