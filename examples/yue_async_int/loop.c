// Host pump for async ExternalEventLoop (yue flavor).
// poll = timed wait (wake event OR any GUI input) then PeekMessage-pump all
// messages (WM_TIMER/WM_PAINT/mouse/keyboard -> yue WndProc).
// wake = auto-reset event SetEvent, called by async's internal waiting thread.
// Contract: callback body must only call this C FFI, no MoonBit refcounting.
// NOTE: ASCII-only comments; cl without /utf-8 reads this file as CP936.
#ifdef _WIN32
#include <windows.h>


static HANDLE g_wake = NULL;

static HANDLE wake_handle(void) {
  if (g_wake == NULL) {
    g_wake = CreateEventW(NULL, FALSE, FALSE, NULL);
  }
  return g_wake;
}

void yue_async_int_wake(void) {
  HANDLE h = wake_handle();
  if (h) {
    SetEvent(h);
  }
}

int yue_async_int_poll(int timeout_ms) {
  HANDLE h = wake_handle();
  DWORD t = timeout_ms < 0 ? INFINITE : (DWORD)timeout_ms;
  MsgWaitForMultipleObjectsEx(1, &h, t, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
  MSG msg;
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
  return 0;
}

#else
// 非 Windows 占位:MoonBit 侧 c_poll/c_wake 已 #cfg(platform="windows")
// 门控,Linux/macOS 不会调用;空实现仅保符号存在、示例可链接。
void yue_async_int_wake(void) {}

int yue_async_int_poll(int timeout_ms) {
  (void)timeout_ms;
  return 0;
}
#endif
