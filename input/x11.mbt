// X11 输入泵真实现的线程侧说明(Linux;Windows 见 windows.mbt 占位)。
//
// 事件获取架构(pump.mbt + native_x11.c):
//   - 专用线程内 XOpenDisplay 独开一条连接(不复用 GTK 主连接:XNextEvent
//     不分类型取事件,复用会吃掉 GDK 的事件);
//   - XI2 选择(XIKeyPress/KeyRelease/ButtonPress/ButtonRelease/Motion,
//     master 设备):GTK3 挂了 XI2 后同窗口层级的 core 键鼠事件被服务器
//     抑制,必须走 XI2;XI2 不可用才落回 core 掩码;
//   - 线程把事件打包成 32B 记录(evtype/detail/keysym/root_x/root_y)入
//     SPSC 环形队列,poll() 每帧取走,翻译在 decode_record(纯函数)。
//
// 关键教训(真机实证,勿回退):
//   1. 主线程内开第二条 X 连接挂 XI2,XISelectEvents 返回成功但事件
//      永不投递(独立进程同代码正常)→ 必须专用线程;
//   2. core XSelectInput 挂 ButtonPress 等掩码在 GTK3 环境回 BadAccess
//      (req=2/code=10)→ XI2 可用时不要叠 core 掩码;
//   3. XIQueryVersion 返回 Status(0=成功),不是 Bool。
