// X11 输入泵 FFI:全部经 native_x11.c 垫片(libX11/libXi 均 dlopen 动态
// 解析,链接期零依赖;Windows 上垫片给 no-op,声明保留保编译)。
// 命名空间 sf_x11_* 避免与真实 Xlib 符号撞名。
//
// 指针一律 UInt64(与 renderers::from_xlib 的 display 传法一致);
// buf 是字节缓冲(Bytes 在原生后端 ABI 即 uint8_t*,C 侧可写)。

///|
/// dlopen libX11/libXi 并解析全部符号;返回 0 = 环境不可用。
extern "c" fn sf_x11_load_libs() -> Int = "sf_x11_load_libs"

///|
/// 诊断:XI2 是否就绪(非 0 = opcode)。
extern "c" fn sf_x11_xi2_ready() -> Int = "sf_x11_xi2_ready"

///|
/// 启动专用输入线程(线程内开连接 + XI2 选择 + 阻塞读取入环)。xids 为
/// LE u64 数组字节流。返回泵句柄,0 = 失败。
#borrow(xids)
extern "c" fn sf_x11_pump_start(xids : Bytes, count : Int) -> UInt64 = "sf_x11_pump_start"

///|
/// 从环形队列取最多 max 条记录写入 out;返回实际条数。
#borrow(out)
extern "c" fn sf_x11_pump_take(pump : UInt64, out : Bytes, max : Int) -> Int = "sf_x11_pump_take"

///|
/// 队列积压条数(诊断)。
extern "c" fn sf_x11_pump_qlen(pump : UInt64) -> Int = "sf_x11_pump_qlen"

///|
/// 停线程并释放(幂等)。
extern "c" fn sf_x11_pump_stop(pump : UInt64) -> Unit = "sf_x11_pump_stop"

///|
/// 根窗口 XID(测试/无宿主窗口时挂事件用);dpy 无效返回 0。
extern "c" fn sf_x11_default_root_window(dpy : UInt64) -> UInt64 = "sf_x11_default_root_window"

///|
/// Int64 位型转 Double(按位重解释;读 XIDeviceEvent 的 root_x/root_y 用)。
extern "c" fn sf_x11_bits_to_f64(bits : Int64) -> Double = "sf_x11_bits_to_f64"

// —— 以下为一次性诊断/一次性连接辅助(default_root_xid 用),泵主路不经 ——

///|
/// 打开独立显示连接(dlopen 的 XOpenDisplay(NULL));失败返回 0。
extern "c" fn sf_x11_open_display() -> UInt64 = "sf_x11_open_display"

///|
extern "c" fn sf_x11_close_display(dpy : UInt64) -> Unit = "sf_x11_close_display"

// —— 指针锁定(FPS 式)命令型入口(PointerLock 机制层用)——
// 在宿主(GDK)自己的 display 上主线程调用;只发请求读回复,不收事件。

///|
/// 抓捕指针到窗口:隐形光标 + confine;返回 0 = 成功(GrabSuccess)。
extern "c" fn sf_x11_grab_pointer(dpy : UInt64, win : UInt64) -> Int = "sf_x11_grab_pointer"

///|
/// 释放抓捕(光标随之恢复)。
extern "c" fn sf_x11_ungrab_pointer(dpy : UInt64) -> Int = "sf_x11_ungrab_pointer"

///|
/// 把指针瞬移到窗口内 (x, y)(回中用;会产生一条落在目标点的 motion)。
extern "c" fn sf_x11_warp_pointer_window(
  dpy : UInt64,
  win : UInt64,
  x : Int,
  y : Int,
) -> Unit = "sf_x11_warp_pointer_window"

///|
/// 当前键盘焦点窗口 XID(失焦检测用)。
extern "c" fn sf_x11_input_focus_window(dpy : UInt64) -> UInt64 = "sf_x11_input_focus_window"

///|
/// 窗口的父窗口 XID(根窗口父=自身;失效返回 0)。
extern "c" fn sf_x11_window_parent(dpy : UInt64, win : UInt64) -> UInt64 = "sf_x11_window_parent"

///|
/// 指针采样:out 写 12 字节 [wx i32][wy i32][btn1 i32](坐标相对锁定
/// 窗口,btn1=左键按住);返回 0 = 不同屏/失败。
#borrow(out)
extern "c" fn sf_x11_query_pointer(dpy : UInt64, win : UInt64, out : Bytes) -> Int = "sf_x11_query_pointer"

///|
/// EWMH 活动窗口(_NET_ACTIVE_WINDOW;0=无 EWMH/读失败)。
extern "c" fn sf_x11_active_window(dpy : UInt64) -> UInt64 = "sf_x11_active_window"
