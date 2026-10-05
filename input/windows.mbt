// Windows 占位(与 renderers::from_hwnd 的 from_hwnd_other.mbt 同一模式):
// 真实实现待铺,占位保包在 Windows 可编译可链接,调用即明确报错指路。
//
// 待铺清单(Win32 消息 → 同一套 InputEvent,状态/控制器零改动):
//   WM_KEYDOWN/WM_SYSKEYDOWN   → KeyDown(VK 码 → KeyCode 映射表)
//   WM_KEYUP/WM_SYSKEYUP       → KeyUp
//   WM_LBUTTONDOWN/UP 等       → MouseDown/MouseUp(POINT → 屏幕坐标)
//   WM_MOUSEMOVE               → MouseMove
//   WM_MOUSEWHEEL(wParam 高字)→ Wheel(0, ±120 归一成 ±1)
//   WM_MOUSEHWHEEL             → Wheel(±1, 0)
// 句柄来源:cube3d_win 已趟通的整窗 HWND(FindWindowA / native_handle)。

///|
/// 打开 Win32 输入泵(占位:尚未实现,真机铺在 Windows 侧做)。
#cfg(platform="windows")
pub fn InputSystem::open_win32(_hwnd : UInt64) -> InputSystem raise Error {
  raise Failure(
    "open_win32 尚未实现:Windows 输入待铺(WM_KEYDOWN/WM_MOUSEMOVE/WM_MOUSEWHEEL → InputEvent);Linux 用 open_x11",
  )
}

///|
/// poll 占位(open_win32 先 raise,正常流程到不了这里;保包可编译)。
#cfg(platform="windows")
pub fn InputSystem::poll(self : InputSystem) -> Array[InputEvent] {
  let out : Array[InputEvent] = []
  ignore(self)
  out
}
