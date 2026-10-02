# three-native [![CI](https://github.com/lb091188/three-native/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/three-native/actions/workflows/ci.yml)

[three.js](https://threejs.org) 的 [MoonBit](https://www.moonbitlang.cn/) 迁移——WebGPU 渲染,3D 场景可直接嵌入 [moonbit-libyue](https://github.com/lb091188/moonbit-libyue) 桌面应用。

[English](https://github.com/lb091188/three-native/blob/master/README.md) | 简体中文

## 核心能力(当前)

**📐 数学库** —— Vector2/3/4、Matrix3/4、Quaternion、Euler、Color、Box3、Sphere、Plane、Ray、Frustum、MathUtils,公式与边界行为对照 three.js r186 源码迁移,不可变风格:

```moonbit
let q = @math3d.Quaternion::from_euler(@math3d.Euler::new(0.4, 0.6, 0.0))
let dir = q.apply(@math3d.Vector3::unit_z())
```

**🌲 场景图** —— Object3D 节点树(平移/旋转/缩放、世界矩阵、add/remove、traverse 遍历),Mesh = 几何体 + 材质:

```moonbit
let scene = @core.Scene::new()
scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
scene.add(@core.Mesh::new(
  @core.BufferGeometry::box(1.2, 1.2, 1.2),
  @core.Material::basic(@math3d.Color::from_hex("#2dd4bf").unwrap()),
))
```

**📷 相机** —— 透视与正交(投影矩阵按 WebGPU 深度域约定 z∈[0,1]):

```moonbit
let camera = @core.PerspectiveCamera::new(60.0, 16.0 / 9.0, 0.1, 100.0)
camera.look_at(@math3d.Vector3::new(1.8, 1.4, 2.6), @math3d.Vector3::zero())
```

**🎮 WebGPU 渲染器** —— 建在 [wgpu-mbt](https://github.com/moonbit-community/wgpu-mbt) 上(Vulkan / Metal / D3D12),WGSL 管线、逐 mesh GPU 资源缓存、深度测试、窗口尺寸自适应。

**🖥 桌面嵌入** —— 与 moonbit-libyue 同窗口混排:yue 负责原生窗口与控件,three-native 拿控件的原生句柄建 GPU surface,3D 视图与按钮/菜单等原生控件并存。

## 架构

```
你的应用(MoonBit)
│
├── three-native ………………… 场景图 / 数学 / 几何 / 材质 / 光源(纯 MoonBit)
│     └── renderers …………… WebGPURenderer:WGSL 管线、GPU 资源缓存、帧调度
│             └── wgpu-mbt …… wgpu-native 绑定(Vulkan / Metal / D3D12)
│
└── moonbit-libyue ……………… 原生窗口与控件树(GTK / Cocoa / Win32)
        └── 句柄对接 ……………… Container 原生句柄 → X11 窗口号 → GPU surface
```

嵌入方式:yue 窗口里放一个 `Container`,经 `@yue.native_handle_view` 取原生控件句柄(Linux 为 `GtkWidget*`),换算出 X11 窗口号后交给 `WebGPURenderer::from_xlib` 建 surface,之后每帧 `render(scene, camera)`。完整代码见 [examples/cube3d](examples/cube3d/main.mbt)。

## 快速开始

前置要求:MoonBit native 工具链(`moonc` ≥ 0.10.14,`moon version --all` 可验证);Linux 渲染需要 Vulkan 驱动(含 lavapipe 软件渲染,无独显可跑)。

```sh
moon new hello3d --user <你的用户名> --name hello3d
cd hello3d
moon add NoahLiu/three-native/math3d
moon add NoahLiu/three-native/core
moon add NoahLiu/three-native/renderers
```

把 `moon.mod` 的 `preferred_target` 改为 `"native"`,再在 `cmd/main/moon.pkg` 里声明要用到的包:

```
import {
  "NoahLiu/three-native/math3d",
  "NoahLiu/three-native/core",
}
```

在 `cmd/main/main.mbt` 里搭一个场景:

```moonbit
fn main {
  let scene = @core.Scene::new()
  scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
  let cube = @core.Mesh::new(
    @core.BufferGeometry::box(1.2, 1.2, 1.2),
    @core.Material::basic(@math3d.Color::from_hex("#2dd4bf").unwrap()),
  )
  scene.add(cube)
  let camera = @core.PerspectiveCamera::new(60.0, 16.0 / 9.0, 0.1, 100.0)
  camera.look_at(
    @math3d.Vector3::new(1.8, 1.4, 2.6),
    @math3d.Vector3::zero(),
  )
  cube.rotation = @math3d.Quaternion::from_euler(
    @math3d.Euler::new(0.4, 0.6, 0.0),
  )
  scene.update_matrix_world()
  println("立方体顶点数:\{cube.mesh.unwrap().geometry.vertex_count()}")
}
```

`moon run cmd/main` 输出 `立方体顶点数:24`。渲染到窗口需要宿主 GUI(取原生句柄建 surface),完整端到端示例见:

```sh
moon run examples/cube3d   # yue 窗口中的旋转立方体,15 秒自动退出
```

几何体与光源在另外两个包,按需添加:`NoahLiu/three-native/geometries`(Sphere/Cylinder/Cone/Circle/Torus)、`NoahLiu/three-native/lights`(环境/方向/半球/点/聚光)。

## 示例

| 示例 | 内容 | 命令 |
|---|---|---|
| [cube3d](examples/cube3d/main.mbt) | yue 窗口中的旋转立方体:场景、相机、渲染器全链路 | `moon run examples/cube3d` |
| [yue_wgpu_window](examples/yue_wgpu_window/main.mbt) | wgpu surface 直接对接 yue 窗口(集成验证用) | `moon run examples/yue_wgpu_window` |

## 当前能力与限制

- ✅ 数学/场景图/相机/几何体/材质与光源数据层,111 项单测;cube3d 在 Linux(X11)真机与 lavapipe 软件渲染下均通过
- 🟡 渲染管线目前仅 Basic(纯色):Lambert/Phong 材质与光源数据层尚未接入 WGSL 光照,纹理尚停留在数据层(未上传采样)
- 🟡 surface 创建走 X11 路径(Linux 已实测);Windows/macOS/Wayland 的窗口对接待铺开
- ❌ loaders / extras / animation 等模块未开始——完整对照见 [docs/coverage-matrix.md](docs/coverage-matrix.md)

## 开发贡献

- **提交门槛**:`moon check && moon test` 全仓零错误零警告
- **新增模块**沿用现有分包结构(math3d / core / lights / geometries / renderers),公式与边界行为以 [three.js 源码](https://github.com/mrdoob/three.js)为准,迁移后在 [docs/coverage-matrix.md](docs/coverage-matrix.md) 更新状态

```sh
moon check && moon test   # 静态检查 + 111 项单测
moon run examples/cube3d  # 端到端冒烟(15 秒自动退出)
```

## 与生态其它 3D 库的关系

mooncakes 上另有 [mizchi/three](https://mooncakes.io/docs/mizchi/three)——three.js 的 FFI 绑定,仅支持 JS 目标(浏览器/Node)与 WebGL 渲染。本库与其互为补充:本库面向 **native 桌面**目标、WebGPU 渲染(wgpu-native)、可嵌入 moonbit-libyue 桌面应用;浏览器场景请使用 mizchi/three。

## 许可证

`three-native` 以 [Apache-2.0](LICENSE) 发布。本项目是独立实现:未复制 [three.js](https://github.com/mrdoob/three.js)(MIT)的任何代码,公式、常数与边界行为对照其源码设计确定。依赖 [wgpu-mbt](https://github.com/moonbit-community/wgpu-mbt)(Apache-2.0)与 [moonbit-libyue](https://github.com/lb091188/moonbit-libyue)(MIT)。
