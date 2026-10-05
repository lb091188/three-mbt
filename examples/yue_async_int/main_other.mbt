// yue_async_int 的非 Windows 占位 main:真实实现(MsgWait 唤醒事件 +
// PeekMessage 泵,async IOCP)在 main.mbt 内 #cfg(platform="windows")
// 门控;Linux 形态见 moonbit-libyue experiment/async-pump-research.md
// (g_main_context_iteration 泵路线)。

#cfg(not(platform="windows"))
fn main {
  println(
    "yue_async_int: Windows 专用示例(MsgWait 泵 + IOCP);Linux 泵路线见 libyue async-pump 调研",
  )
}
