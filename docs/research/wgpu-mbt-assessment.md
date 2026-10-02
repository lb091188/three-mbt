# wgpu-mbt 依赖成熟度评估(Go/No-Go)

评估日期:2026-10-02 | 评估对象:`Milky2018/wgpu_mbt@0.16.2`(锁上游 wgpu-native `v29.0.1.1`,commit 6aed509)

## 结论:附条件 Go

作为 three-mbt 的 GPU 基础依赖引入,条件见「管理动作」。任何情况下 math/core 层不依赖它,退路只影响渲染器层。

## 事实清单

### 能力面(符号级)

- 绑定覆盖:instance/adapter/device/queue、surface 全平台原生构造器(xlib/xcb/wayland/HWND/swap-chain-panel/Android + NSView/CAMetalLayer)、buffer/texture/sampler/bind group、render/compute pipeline、shader(WGSL/GLSL)、命令编码、query set、instance/device extras、异步 future 式请求。
- 分发机制:静态为默认(prebuild 钩子自动下载并链接已校验的上游静态归档,下游零链接参数);动态可选(`MBT_WGPU_LINK_MODE=dynamic`)。
- 钩子:`--moonbit-unstable-prebuild` + `build.js`(node 实现的 Python 对等物,与 yue 的 prebuild.py 同机制)。

### 本地实测(我们)

- `moon add` 即用,静态库自动下载链接,零配置;
- Linux headless Vulkan:adapter/device/queue 创建链路通过(`tests/wgpu_smoke`)。

### 维护画像(按修正事实,打折后)

- 仓库挂 moonbit-community 组织,但**全部提交由 Milky2018 一人完成**,6 stars / 1 fork——bus factor 为 1;
- 提交节奏:6-7 月密集、7 月中至 9 月初一段空档、最近提交 9 月 7 日;"单人低频但持续",非社区化多人项目;
- 文档齐全(README/平台支持状态/生命周期验证/覆盖审计)。

### 质量边界

- 覆盖审计明说:**只查符号存在性,不查行为**;某些入口在特定 wgpu-native 构建里可能未实现或 panic;
- 平台矩阵的关键倒挂:唯一完成**窗口化真机验证**的是 macOS;Linux/Windows 仅 headless Vulkan(Lavapipe)+ surface 描述符输入校验——**真实窗口句柄上的 present/acquire 无人验证**,恰是本项目要走的那段路。

## 管理动作

1. **锁版本**:钉 `0.16.2` + wgpu-native `v29.0.1.1`;不追最新,升级走专门批次(重新评估行为覆盖)。
2. **P0 spike**:X11 surface 窗口化真机 present 列为第一优先级验证——整个依赖链里唯一没被任何人验证过的环节;yue×wgpu 双钩子共存(build.js × prebuild.py)并入同一 spike。
3. **fork 退路预案**:上游为薄绑定(C API 直映射,37 个源文件)、Apache-2.0;若维护中断,静态库已钉死照常可用,必要时 fork 到本组织自持,接手成本可控。
4. **反哺**:趟通 Linux/Windows 窗口化后把坑位与修复反馈上游(申报材料"参与生态建设"的实证)。

## 生态位(非重复声明)

wgpu-mbt = WebGPU 地基绑定(相当于浏览器世界的 WebGPU 标准);three-mbt = 地基上的场景库(three.js 层)。二者是 WebGL 与 three.js 的关系,非重复建设。
