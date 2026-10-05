// Host pump for async ExternalEventLoop (yue flavor).
// poll = timed wait (wake event OR any GUI input) then PeekMessage-pump all
// messages (WM_TIMER/WM_PAINT/mouse/keyboard -> yue WndProc).
// wake = auto-reset event SetEvent, called by async's internal waiting thread.
// Contract: callback body must only call this C FFI, no MoonBit refcounting.
// NOTE: ASCII-only comments; cl without /utf-8 reads this file as CP936.
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
