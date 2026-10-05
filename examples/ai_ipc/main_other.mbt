// ai_ipc 的非 Windows 占位 main:真实实现(GetTickCount 计时 + cmd.exe
// 冒烟 + node 子进程往返)在 main.mbt 内 #cfg(platform="windows") 门控
// (GetTickCount 为 Win32 符号);Linux 可后续按需补 clock_gettime 版。

#cfg(not(platform="windows"))
fn main {
  println("ai_ipc: Windows 专用示例(GetTickCount + cmd.exe);Linux 版待按需补充")
}
