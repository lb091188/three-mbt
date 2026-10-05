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

#endif /* _WIN32 */
