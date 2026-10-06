/* X11 输入事件泵垫片:动态加载 libX11/libXi(仿 wgpu_mbt wgpu_dynload.c
 * 思路),链接期零 X11 依赖 —— moon test / 交叉构建在无 X11 开发文件的
 * 环境也能过。Windows 上给 no-op(输入真实现走 Win32,见 input/windows.mbt
 * 待铺清单)。
 *
 * 架构(真机实证得出,勿回退):
 *  1. 专用线程内 XOpenDisplay 独开一条连接并独占读写(主线程开第二条
 *     连接挂 XI2,事件永不投递;独立线程同代码正常);
 *  2. XI2 选择(XIKeyPress..XI_Motion,master 设备):GTK3 挂了 XI2 后
 *     同窗口层级的 core 键鼠事件被服务器抑制,必须走 XI2;core
 *     XSelectInput 叠加同掩码会被回 BadAccess(req=2/code=10);
 *  3. XIQueryVersion 返回 Status(0=成功),不是 Bool;
 *  4. 线程把事件打包成 32B 记录 [evtype i32][detail i32][keysym u64]
 *     [rx f64][ry f64] 入 SPSC 环形队列,InputEvent 翻译留在 MoonBit
 *     纯函数 decode_record(单测覆盖)。
 */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32

/* Windows:无 X11,no-op(MoonBit 侧 open_x11 拿到 0 会明确报错;
 * Windows 正路是 open_win32,尚未铺)。 */
int32_t sf_x11_load_libs(void) { return 0; }
int32_t sf_x11_xi2_ready(void) { return 0; }
uint64_t sf_x11_pump_start(const uint8_t *xids, int32_t count) {
  (void)xids; (void)count; return 0;
}
void sf_x11_pump_watch(uint64_t pump, const uint8_t *xids, int32_t count) {
  (void)pump; (void)xids; (void)count;
}
int32_t sf_x11_pump_take(uint64_t pump, uint8_t *out, int32_t max) {
  (void)pump; (void)out; (void)max; return 0;
}
int32_t sf_x11_pump_qlen(uint64_t pump) { (void)pump; return 0; }
void sf_x11_pump_stop(uint64_t pump) { (void)pump; }
uint64_t sf_x11_default_root_window(uint64_t dpy) { (void)dpy; return 0; }
uint64_t sf_x11_open_display(void) { return 0; }
void sf_x11_close_display(uint64_t dpy) { (void)dpy; }
int32_t sf_x11_grab_pointer(uint64_t dpy, uint64_t win) {
  (void)dpy; (void)win; return 1;
}
int32_t sf_x11_ungrab_pointer(uint64_t dpy) { (void)dpy; return 1; }
void sf_x11_warp_pointer_window(uint64_t dpy, uint64_t win, int32_t x,
                                int32_t y) {
  (void)dpy; (void)win; (void)x; (void)y;
}
uint64_t sf_x11_input_focus_window(uint64_t dpy) { (void)dpy; return 0; }
int32_t sf_x11_query_pointer(uint64_t dpy, uint64_t win, uint8_t *out) {
  (void)dpy; (void)win; (void)out; return 0;
}
uint64_t sf_x11_active_window(uint64_t dpy) { (void)dpy; return 0; }
double sf_x11_bits_to_f64(int64_t bits) { (void)bits; return 0.0; }

#else /* !_WIN32 */

#include <dlfcn.h>
#include <pthread.h>
#include <poll.h>
#include <unistd.h>

typedef int Bool_;
typedef void *(*open_display_fn)(const char *);
typedef int (*close_display_fn)(void *);
typedef int (*pending_fn)(void *);
typedef int (*next_event_fn)(void *, void *);
typedef unsigned long (*lookup_keysym_fn)(void *, int);
typedef int (*query_extension_fn)(void *, const char *, int *, int *, int *);
typedef Bool_ (*xi_query_version_fn)(void *, int *, int *);
typedef int (*xi_select_events_fn)(void *, unsigned long, void *, int);
typedef Bool_ (*get_event_data_fn)(void *, void *);
typedef void (*free_event_data_fn)(void *, void *);
typedef unsigned long (*xkb_keycode_to_keysym_fn)(void *, unsigned char, int,
                                                  int);
typedef int (*default_screen_fn)(void *);
typedef unsigned long (*root_window_fn)(void *, int);

/* 指针锁定(FPS 式)命令型入口:grab/warp/focus 查询只发请求读回复、
 * 不收事件,可在宿主(GDK)自己的 display 上主线程内直接调(与泵的
 * "第二连接收不到事件"教训不冲突 —— 那是事件投递问题,不是请求
 * 回复问题)。XGrabPointer 的 cursor 参数即抓捕期间显示的光标,传
 * 隐形光标一并解决隐藏指针。 */
typedef int (*grab_pointer_fn)(void *, unsigned long, int, unsigned int,
                               int, int, unsigned long, unsigned long,
                               unsigned long);
typedef int (*ungrab_pointer_fn)(void *, unsigned long);
typedef void (*warp_pointer_fn)(void *, unsigned long, unsigned long, int,
                                int, unsigned int, unsigned int, int, int);
typedef int (*flush_fn)(void *);
typedef int (*sync_fn)(void *, int);
typedef unsigned long (*create_bitmap_fn)(void *, unsigned long, const char *,
                                          unsigned int, unsigned int);
typedef unsigned long (*create_pcursor_fn)(void *, unsigned long,
                                           unsigned long, void *, void *,
                                           unsigned int, unsigned int);
typedef int (*get_input_focus_fn)(void *, unsigned long *, int *);
typedef int (*query_tree_fn)(void *, unsigned long, unsigned long *,
                             unsigned long *, unsigned long **,
                             unsigned int *);
typedef int (*xfree_fn)(void *);
typedef int (*query_pointer_fn)(void *, unsigned long, unsigned long *,
                                unsigned long *, int *, int *, int *,
                                int *, unsigned int *);
typedef unsigned long (*intern_atom_fn)(void *, const char *, int);
typedef int (*get_property_fn)(void *, unsigned long, unsigned long, long,
                               long, int, unsigned long, unsigned long *,
                               int *, unsigned long *, unsigned long *,
                               unsigned char **);

/* XIEventMask { int deviceid; int mask_len; unsigned char *mask; } */
typedef struct {
  int deviceid;
  int mask_len;
  unsigned char *mask;
} sf_xi_event_mask;

/* XGenericEventCookie 字段偏移(LP64):extension@32 evtype@36 data@48 */
#define SF_OFF_COOKIE_EXT 32
#define SF_OFF_COOKIE_EVT 36
#define SF_OFF_COOKIE_DATA 48
/* XIDeviceEvent(Xlib 版)字段偏移:detail@56 root_x@88 root_y@96;
 * core XKeyEvent/XButtonEvent:x_root@72 y_root@76 keycode/button@84 */
#define SF_OFF_DEV_DETAIL 56
#define SF_OFF_DEV_ROOTX 88
#define SF_OFF_DEV_ROOTY 96
#define SF_OFF_CORE_ROOTX 72
#define SF_OFF_CORE_KEYCODE 84

#define SF_REC 32
#define SF_RING 512

typedef struct {
  void *dpy;
  int fd;
  volatile int running;
  volatile int ready;
  long head;
  long tail;
  pthread_t th;
  unsigned char recs[SF_REC * SF_RING];
} sf_pump;

typedef struct {
  sf_pump *p;
  uint8_t *ids;
  int32_t count;
} sf_pump_init;

static void *g_x11_lib = NULL;
static void *g_xi_lib = NULL;
static int g_xi2_opcode = 0;
static int g_loaded = 0;
static open_display_fn p_open_display;
static close_display_fn p_close_display;
static pending_fn p_pending;
static next_event_fn p_next_event;
static lookup_keysym_fn p_lookup_keysym;
static query_extension_fn p_query_extension;
static xi_query_version_fn p_xi_query_version;
static xi_select_events_fn p_xi_select_events;
static get_event_data_fn p_get_event_data;
static free_event_data_fn p_free_event_data;
static xkb_keycode_to_keysym_fn p_xkb_keysym;
static default_screen_fn p_default_screen;
static root_window_fn p_root_window;
static grab_pointer_fn p_grab_pointer;
static ungrab_pointer_fn p_ungrab_pointer;
static warp_pointer_fn p_warp_pointer;
static flush_fn p_flush;
static sync_fn p_sync;
static create_bitmap_fn p_create_bitmap;
static create_pcursor_fn p_create_pcursor;
static get_input_focus_fn p_get_input_focus;
static query_tree_fn p_query_tree;
static xfree_fn p_xfree;
static query_pointer_fn p_query_pointer;
static intern_atom_fn p_intern_atom;
static get_property_fn p_get_property;
static unsigned long g_atom_active = 0; /* _NET_ACTIVE_WINDOW,懒取 */
/* 隐形光标缓存:每 display 一枚,grab 期间常驻(建后不 free) */
static void *g_lock_cursor_dpy = NULL;
static unsigned long g_lock_cursor = 0;

static int sf_load(void) {
  if (g_loaded) {
    return g_x11_lib != NULL;
  }
  g_loaded = 1;
  /* 不调用 XInitThreads:泵线程独占自己的连接,单线程单连接无需锁;
   * 迟到的 XInitThreads(GDK 已先开连接)属未定义行为,实测会毒化
   * 后续连接的事件投递。 */
  const char *names[] = { "libX11.so.6", "libX11.so", NULL };
  for (int i = 0; names[i] != NULL && g_x11_lib == NULL; i++) {
    g_x11_lib = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
  }
  if (g_x11_lib == NULL) {
    return 0;
  }
  /* libXi 只承载 XI2 入口;缺了就降级 core 路径。 */
  const char *xi_names[] = { "libXi.so.6", "libXi.so.2", "libXi.so", NULL };
  for (int i = 0; xi_names[i] != NULL && g_xi_lib == NULL; i++) {
    g_xi_lib = dlopen(xi_names[i], RTLD_NOW | RTLD_LOCAL);
  }
#define SF_SYM(var, lib, name)                                                 \
  do {                                                                         \
    p_##var = (typeof(p_##var))dlsym(lib, name);                               \
    if (p_##var == NULL) {                                                     \
      if (lib == g_x11_lib) {                                                  \
        g_x11_lib = NULL;                                                      \
        return 0;                                                              \
      }                                                                        \
      g_xi_lib = NULL;                                                         \
    }                                                                          \
  } while (0)
  SF_SYM(open_display, g_x11_lib, "XOpenDisplay");
  SF_SYM(close_display, g_x11_lib, "XCloseDisplay");
  SF_SYM(pending, g_x11_lib, "XPending");
  SF_SYM(next_event, g_x11_lib, "XNextEvent");
  SF_SYM(lookup_keysym, g_x11_lib, "XLookupKeysym");
  SF_SYM(query_extension, g_x11_lib, "XQueryExtension");
  SF_SYM(get_event_data, g_x11_lib, "XGetEventData");
  SF_SYM(free_event_data, g_x11_lib, "XFreeEventData");
  SF_SYM(xkb_keysym, g_x11_lib, "XkbKeycodeToKeysym");
  SF_SYM(default_screen, g_x11_lib, "XDefaultScreen");
  SF_SYM(root_window, g_x11_lib, "XRootWindow");
  SF_SYM(grab_pointer, g_x11_lib, "XGrabPointer");
  SF_SYM(ungrab_pointer, g_x11_lib, "XUngrabPointer");
  SF_SYM(warp_pointer, g_x11_lib, "XWarpPointer");
  SF_SYM(flush, g_x11_lib, "XFlush");
  SF_SYM(sync, g_x11_lib, "XSync");
  SF_SYM(create_bitmap, g_x11_lib, "XCreateBitmapFromData");
  SF_SYM(create_pcursor, g_x11_lib, "XCreatePixmapCursor");
  SF_SYM(get_input_focus, g_x11_lib, "XGetInputFocus");
  SF_SYM(query_tree, g_x11_lib, "XQueryTree");
  SF_SYM(intern_atom, g_x11_lib, "XInternAtom");
  SF_SYM(get_property, g_x11_lib, "XGetWindowProperty");
  SF_SYM(xfree, g_x11_lib, "XFree");
  SF_SYM(query_pointer, g_x11_lib, "XQueryPointer");
  if (g_xi_lib != NULL) {
    SF_SYM(xi_query_version, g_xi_lib, "XIQueryVersion");
    SF_SYM(xi_select_events, g_xi_lib, "XISelectEvents");
  }
#undef SF_SYM
  return 1;
}

/* SPSC:单写(pump 线程)单读(MoonBit 主线程),head/tail 原子读写。 */
static void sf_push(sf_pump *p, int32_t evtype, int32_t detail,
                    unsigned long keysym, double rx, double ry) {
  long head = __atomic_load_n(&p->head, __ATOMIC_RELAXED);
  long tail = __atomic_load_n(&p->tail, __ATOMIC_ACQUIRE);
  if (head - tail >= SF_RING) {
    return; /* 队列满:丢事件好过阻塞渲染 */
  }
  unsigned char *r = p->recs + (head % SF_RING) * SF_REC;
  int32_t klo = (int32_t)(keysym & 0xFFFFFFFFUL);
  int32_t khi = (int32_t)(keysym >> 32);
  int32_t *w = (int32_t *)r;
  w[0] = evtype;
  w[1] = detail;
  w[2] = klo;
  w[3] = khi;
  memcpy(r + 16, &rx, 8);
  memcpy(r + 24, &ry, 8);
  __atomic_store_n(&p->head, head + 1, __ATOMIC_RELEASE);
}

static int sf_pump_error_handler(void *dpy, void *err) {
  /* 静默吞掉:Xlib 默认处理器遇协议错误打印并 exit(1) */
  (void)dpy;
  (void)err;
  return 0;
}

/* 泵线程:独占 dpy 的全部 Xlib 调用(无跨线程访问,不需要 XInitThreads)。 */
static void *sf_pump_thread(void *arg) {
  sf_pump_init *init = (sf_pump_init *)arg;
  sf_pump *p = init->p;
  uint8_t *ids = init->ids;
  int32_t count = init->count;
  free(init);
  if (!sf_load()) {
    p->running = 0;
    p->ready = 1;
    return NULL;
  }
  void *dpy = p_open_display(NULL);
  if (dpy == NULL) {
    p->running = 0;
    p->ready = 1;
    return NULL;
  }
  p->dpy = dpy;
  /* 吞掉本连接的异步 X 错误(如窗口已销毁的 BadWindow):Xlib 默认
   * 处理器会打印并 exit(1),输入泵绝不能带崩宿主。安装是线程内的
   * 全局操作,但此后只有本线程使用本连接,不影响 GDK。 */
  typedef int (*err_handler_fn)(void *, void *);
  typedef err_handler_fn (*set_err_fn)(err_handler_fn);
  set_err_fn seh = (set_err_fn)dlsym(g_x11_lib, "XSetErrorHandler");
  if (seh != NULL) {
    seh(sf_pump_error_handler);
  }
  /* XI2 协商 */
  int ev_base = 0, err_base = 0;
  int major = 2, minor = 2;
  g_xi2_opcode = 0;
  int xi2 = 0;
  if (p_xi_query_version != NULL && p_xi_select_events != NULL &&
      p_query_extension(dpy, "XInputExtension", &g_xi2_opcode, &ev_base,
                        &err_base) &&
      p_xi_query_version(dpy, &major, &minor) == 0) {
    xi2 = 1;
  } else {
    g_xi2_opcode = 0;
  }
  /* 选择监听窗口:XI2 可用只走 XI2(core 掩码在 GTK3 环境会 BadAccess 且
   * 抑制 XI2 投递);不可用落回 core 掩码。 */
  unsigned char xi_mask = (unsigned char)124;
  for (int32_t i = 0; i < count; i++) {
    unsigned long w;
    memcpy(&w, ids + (size_t)i * 8, 8);
    if (xi2) {
      sf_xi_event_mask em;
      em.deviceid = 1; /* XIAllMasterDevices */
      em.mask_len = 1;
      em.mask = &xi_mask;
      p_xi_select_events(dpy, w, &em, 1);
    } else {
      /* KeyPress|KeyRelease|ButtonPress|ButtonRelease|PointerMotion|
       * ButtonMotion = 335,经 XChangeWindowAttributes 同义请求 */
      typedef int (*select_input_fn)(void *, unsigned long, long);
      select_input_fn si = (select_input_fn)dlsym(g_x11_lib, "XSelectInput");
      if (si != NULL) {
        si(dpy, w, 335L);
      }
    }
  }
  /* 关键:XISelectEvents 可能是单向请求(_XSend 不flush),不主动 flush
   * 它就永远躺在输出缓冲里 → 服务器没收到选择 → 不投递 → poll(fd) 永远
   * 不响 → 死锁(真机实证:XSync 后事件立刻开始投递)。 */
  typedef int (*sync_fn)(void *, Bool_);
  sync_fn xs = (sync_fn)dlsym(g_x11_lib, "XSync");
  if (xs != NULL) {
    xs(dpy, 0);
  }
  /* XConnectionNumber 用于 poll(2) 等待事件可读;拿不到就退化轮询 */
  typedef int (*conn_num_fn)(void *);
  conn_num_fn cn = (conn_num_fn)dlsym(g_x11_lib, "XConnectionNumber");
  p->fd = cn != NULL ? cn(dpy) : -1;
  __atomic_store_n(&p->ready, 1, __ATOMIC_RELEASE);
  while (p->running) {
    struct pollfd pfd = { p->fd, POLLIN, 0 };
    int r = (p->fd >= 0) ? poll(&pfd, 1, 50) : (usleep(50000), 0);
    if (r <= 0) {
      continue;
    }
    while (p->running && p_pending(p->dpy) > 0) {
      unsigned char ev[128];
      if (p_next_event(p->dpy, ev) == 0) {
        break;
      }
      int32_t type;
      memcpy(&type, ev, 4);
      if (type == 35) { /* GenericEvent */
        int32_t ext, evtype;
        memcpy(&ext, ev + SF_OFF_COOKIE_EXT, 4);
        memcpy(&evtype, ev + SF_OFF_COOKIE_EVT, 4);
        if (ext != g_xi2_opcode) {
          continue; /* 其他扩展(XKB 等)不消费 */
        }
        if (!p_get_event_data(p->dpy, ev)) {
          continue;
        }
        void *dev;
        memcpy(&dev, ev + SF_OFF_COOKIE_DATA, 8);
        int32_t detail = 0;
        double rx = 0.0, ry = 0.0;
        unsigned long keysym = 0;
        memcpy(&detail, (unsigned char *)dev + SF_OFF_DEV_DETAIL, 4);
        memcpy(&rx, (unsigned char *)dev + SF_OFF_DEV_ROOTX, 8);
        memcpy(&ry, (unsigned char *)dev + SF_OFF_DEV_ROOTY, 8);
        if (evtype == 2 || evtype == 3) { /* XI_KeyPress/Release */
          if (p_xkb_keysym != NULL) {
            keysym = p_xkb_keysym(dpy, (unsigned char)detail, 0, 0);
          }
        }
        p_free_event_data(p->dpy, ev);
        sf_push(p, evtype, detail, keysym, rx, ry);
      } else if (type >= 2 && type <= 6) {
        /* core 事件兜底(无 XI2 的环境):LP64 XEvent 布局,事件结构同头:
         * x@64 y@68 x_root@72 y_root@76,keycode/button@84 */
        int32_t detail = 0;
        double rx = 0.0, ry = 0.0;
        unsigned long keysym = 0;
        int32_t xy[4];
        memcpy(xy, ev + 64, 16);
        rx = (double)xy[2];
        ry = (double)xy[3];
        if (type == 2 || type == 3 || type == 4 || type == 5) {
          memcpy(&detail, ev + SF_OFF_CORE_KEYCODE, 4);
        }
        if (type == 2 || type == 3) {
          keysym = p_lookup_keysym(ev, 0);
        }
        sf_push(p, type, detail, keysym, rx, ry);
      }
    }
  }
  p_close_display(dpy);
  return NULL;
}

int32_t sf_x11_load_libs(void) { return sf_load() ? 1 : 0; }

int32_t sf_x11_xi2_ready(void) { return g_xi2_opcode; }

uint64_t sf_x11_pump_start(const uint8_t *xids, int32_t count) {
  if (!sf_load() || count < 0 || (count > 0 && xids == NULL)) {
    return 0;
  }
  sf_pump *p = (sf_pump *)calloc(1, sizeof(sf_pump));
  if (p == NULL) {
    return 0;
  }
  uint8_t *ids = (uint8_t *)calloc(count > 0 ? (size_t)count * 8 : 1, 1);
  if (ids == NULL) {
    free(p);
    return 0;
  }
  if (count > 0) {
    memcpy(ids, xids, (size_t)count * 8);
  }
  sf_pump_init *init = (sf_pump_init *)malloc(sizeof(sf_pump_init));
  if (init == NULL) {
    free(ids);
    free(p);
    return 0;
  }
  init->p = p;
  init->ids = ids;
  init->count = count;
  p->running = 1; /* calloc 清零后必须显式置位,否则线程循环直接退出 */
  if (pthread_create(&p->th, NULL, sf_pump_thread, init) != 0) {
    free(init);
    free(ids);
    free(p);
    return 0;
  }
  /* 握手:线程完成 open+select 后置 ready;失败时 running 清零 */
  for (int i = 0; i < 1000 &&
                  !__atomic_load_n(&p->ready, __ATOMIC_ACQUIRE) &&
                  __atomic_load_n(&p->running, __ATOMIC_RELAXED);
       i++) {
    usleep(10000);
  }
  if (!p->ready) {
    /* 线程已自行置 running=0;join 回收,统一释放 */
    pthread_join(p->th, NULL);
    free(ids);
    free(p);
    return 0;
  }
  return (uint64_t)p;
}

void sf_x11_pump_watch(uint64_t pump, const uint8_t *xids, int32_t count) {
  /* 运行中加挂需要跨线程操作 dpy;当前示例无此需求,留空:
   * 需要更多窗口时在 pump_start 的 xids 里一次给全。 */
  (void)pump; (void)xids; (void)count;
}

int32_t sf_x11_pump_take(uint64_t pump, uint8_t *out, int32_t max) {
  sf_pump *p = (sf_pump *)pump;
  if (p == NULL || out == NULL || max <= 0) {
    return 0;
  }
  int32_t taken = 0;
  long head = __atomic_load_n(&p->head, __ATOMIC_ACQUIRE);
  while (taken < max && p->tail < head) {
    memcpy(out + (size_t)taken * SF_REC, p->recs + (p->tail % SF_RING) * SF_REC,
           SF_REC);
    p->tail++;
    taken++;
  }
  return taken;
}

int32_t sf_x11_pump_qlen(uint64_t pump) {
  sf_pump *p = (sf_pump *)pump;
  if (p == NULL) {
    return 0;
  }
  long head = __atomic_load_n(&p->head, __ATOMIC_RELAXED);
  return (int32_t)(head - p->tail);
}

void sf_x11_pump_stop(uint64_t pump) {
  sf_pump *p = (sf_pump *)pump;
  if (p == NULL) {
    return;
  }
  p->running = 0;
  /* 线程 poll 超时 50ms 内退出并关连接;join 回收后再释放,杜绝
   * use-after-free(此前 sleep+free 在线程侧读已释放内存)。 */
  pthread_join(p->th, NULL);
  free(p);
}

uint64_t sf_x11_default_root_window(uint64_t dpy) {
  if (!sf_load() || dpy == 0) {
    return 0;
  }
  return (uint64_t)p_root_window((void *)dpy, p_default_screen((void *)dpy));
}

uint64_t sf_x11_open_display(void) {
  if (!sf_load()) {
    return 0;
  }
  return (uint64_t)p_open_display(NULL);
}

void sf_x11_close_display(uint64_t dpy) {
  if (dpy != 0) {
    p_close_display((void *)dpy);
  }
}

double sf_x11_bits_to_f64(int64_t bits) {
  double out;
  memcpy(&out, &bits, sizeof(out));
  return out;
}

/* —— 指针锁定(FPS 式)命令型入口 ——

owner_events=1 且抓捕窗口属本进程(GDK),事件仍按原选择投递给宿主
(宿主照收 motion → yue on_mouse_move 不受影响);confine_to=抓捕窗口
防指针逃出;cursor=隐形光标。GrabModeAsync=1(不冻结事件流)。
事件掩码:ButtonPress(1<<2)|ButtonRelease(1<<3)|PointerMotion(1<<6)。 */
static unsigned long sf_ensure_invisible_cursor(void *dpy) {
  if (g_lock_cursor_dpy == dpy && g_lock_cursor != 0) {
    return g_lock_cursor;
  }
  unsigned long root = p_root_window(dpy, p_default_screen(dpy));
  char zero = 0;
  unsigned long bmp = p_create_bitmap(dpy, root, &zero, 1, 1);
  if (bmp == 0) {
    return 0;
  }
  unsigned char color[32]; /* XColor 置零(LP64 实占 24B),32B 余量 */
  memset(color, 0, sizeof(color));
  unsigned long cur = p_create_pcursor(dpy, bmp, bmp, (void *)color,
                                       (void *)color, 0, 0);
  if (cur != 0) {
    g_lock_cursor_dpy = dpy;
    g_lock_cursor = cur;
  }
  return cur;
}

int32_t sf_x11_grab_pointer(uint64_t dpy, uint64_t win) {
  if (!sf_load() || dpy == 0 || win == 0) {
    return 1;
  }
  unsigned long cur = sf_ensure_invisible_cursor((void *)dpy);
  int r = p_grab_pointer((void *)dpy, (unsigned long)win, 1 /*owner_events*/,
                         (1u << 2) | (1u << 3) | (1u << 6) /*按钮+移动*/,
                         1 /*GrabModeAsync*/, 1 /*GrabModeAsync*/,
                         (unsigned long)win /*confine_to*/, cur,
                         0 /*CurrentTime*/);
  p_sync((void *)dpy, 0);
  return r; /* 0 = GrabSuccess */
}

int32_t sf_x11_ungrab_pointer(uint64_t dpy) {
  if (!sf_load() || dpy == 0) {
    return 1;
  }
  p_ungrab_pointer((void *)dpy, 0 /*CurrentTime*/);
  p_sync((void *)dpy, 0);
  return 0;
}

void sf_x11_warp_pointer_window(uint64_t dpy, uint64_t win, int32_t x,
                                int32_t y) {
  if (!sf_load() || dpy == 0 || win == 0) {
    return;
  }
  p_warp_pointer((void *)dpy, 0 /*None=全屏源*/, (unsigned long)win, 0, 0, 0,
                 0, x, y);
  p_flush((void *)dpy);
}

uint64_t sf_x11_input_focus_window(uint64_t dpy) {
  if (!sf_load() || dpy == 0) {
    return 0;
  }
  unsigned long focus = 0;
  int revert = 0;
  p_get_input_focus((void *)dpy, &focus, &revert);
  return (uint64_t)focus;
}

/* 锁定窗口的父窗口(XQueryTree 只取 parent;根窗口父=自身)。
 * 失焦判定用:键盘焦点在顶层窗口(XGetInputFocus),而锁定的是
 * 宿主容器子窗口 —— 需沿父链上溯比对,不能直接等值。 */
uint64_t sf_x11_window_parent(uint64_t dpy, uint64_t win) {
  if (!sf_load() || dpy == 0 || win == 0) {
    return 0;
  }
  unsigned long root = 0, parent = 0, *children = NULL;
  unsigned int nchildren = 0;
  if (!p_query_tree((void *)dpy, (unsigned long)win, &root, &parent,
                    &children, &nchildren)) {
    return 0;
  }
  if (children != NULL) {
    p_xfree(children); /* XQueryTree 的 children 数组归调用方释放 */
  }
  return (uint64_t)parent;
}

#endif /* _WIN32 */

/* 指针采样(锁定差分/按钮轮询;core grab 抑制 GDK/XI2 事件投递,采样走
 * 请求-回复不受影响):win_x/win_y 相对锁定窗口,mask 含 Button1Mask。
 * out 写 12 字节 [wx i32][wy i32][btn1 i32];返回 0=不同屏/失败。 */
int32_t sf_x11_query_pointer(uint64_t dpy, uint64_t win, uint8_t *out) {
  if (!sf_load() || dpy == 0 || win == 0 || out == NULL) {
    return 0;
  }
  unsigned long root = 0, child = 0;
  int rx = 0, ry = 0, wx = 0, wy = 0;
  unsigned int mask = 0;
  if (!p_query_pointer((void *)dpy, (unsigned long)win, &root, &child, &rx,
                       &ry, &wx, &wy, &mask)) {
    return 0;
  }
  int32_t *w = (int32_t *)out;
  w[0] = wx;
  w[1] = wy;
  w[2] = (mask & 0x0100u) ? 1 : 0; /* Button1Mask */
  return 1;
}

/* EWMH 活动窗口(_NET_ACTIVE_WINDOW)。Mutter 把键盘焦点放在独立辅助
 * 窗口(XGetInputFocus 返回的客户窗口 XID+1 之类),祖先链比对会误判
 * 失焦;_NET_ACTIVE_WINDOW 是 WM 维护的客户顶层口径,跨 WM 标准。
 * 返回 0 = 无 EWMH/读失败(调用方回退 XGetInputFocus 路径)。 */
uint64_t sf_x11_active_window(uint64_t dpy) {
  if (!sf_load() || dpy == 0) {
    return 0;
  }
  if (g_atom_active == 0) {
    g_atom_active = p_intern_atom((void *)dpy, "_NET_ACTIVE_WINDOW", 1);
    if (g_atom_active == 0) {
      return 0;
    }
  }
  unsigned long root = p_root_window((void *)dpy, p_default_screen((void *)dpy));
  unsigned long actual_type = 0;
  int actual_format = 0;
  unsigned long nitems = 0, bytes_after = 0;
  unsigned char *data = NULL;
  int r = p_get_property((void *)dpy, root, g_atom_active, 0, 1, 0, 0,
                         &actual_type, &actual_format, &nitems, &bytes_after,
                         &data);
  uint64_t out = 0;
  if (r == 0 && data != NULL && nitems >= 1 && actual_format == 32) {
    out = (uint64_t)((unsigned long *)data)[0];
  }
  if (data != NULL) {
    p_xfree(data);
  }
  return out;
}
