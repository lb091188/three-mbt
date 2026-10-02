# three-mbt [![CI](https://github.com/lb091188/three-mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/three-mbt/actions/workflows/ci.yml)

A [MoonBit](https://www.moonbitlang.com/) port of [three.js](https://threejs.org) — WebGPU rendering, with 3D scenes embeddable in [moonbit-libyue](https://github.com/lb091188/moonbit-libyue) desktop apps.

English | [简体中文](https://github.com/lb091188/three-mbt/blob/master/README_ZH.md)

## What's in (current)

**📐 Math** — Vector2/3/4, Matrix3/4, Quaternion, Euler, Color, Box3, Sphere, Plane, Ray, Frustum, MathUtils. Formulas and edge-case behavior ported against the three.js r186 source, immutable style:

```moonbit
let q = @math3d.Quaternion::from_euler(@math3d.Euler::new(0.4, 0.6, 0.0))
let dir = q.apply(@math3d.Vector3::unit_z())
```

**🌲 Scene graph** — an Object3D node tree (position/rotation/scale, world matrices, add/remove, traverse); a Mesh is geometry + material:

```moonbit
let scene = @core.Scene::new()
scene.background = Some(@math3d.Color::from_hex("#101822").unwrap())
scene.add(@core.Mesh::new(
  @core.BufferGeometry::box(1.2, 1.2, 1.2),
  @core.Material::basic(@math3d.Color::from_hex("#2dd4bf").unwrap()),
))
```

**📷 Cameras** — perspective and orthographic (projection matrices follow the WebGPU depth convention z∈[0,1]):

```moonbit
let camera = @core.PerspectiveCamera::new(60.0, 16.0 / 9.0, 0.1, 100.0)
camera.look_at(@math3d.Vector3::new(1.8, 1.4, 2.6), @math3d.Vector3::zero())
```

**🎮 WebGPU renderer** — built on [wgpu-mbt](https://github.com/moonbit-community/wgpu-mbt) (Vulkan / Metal / D3D12): WGSL pipelines, per-mesh GPU resource caching, depth testing, window-resize handling.

**🖥 Desktop embedding** — mixes with moonbit-libyue in the same window: yue provides the native window and widgets, three-mbt takes the widget's native handle to create the GPU surface, so a 3D view coexists with native buttons and menus.

## Architecture

```
your app (MoonBit)
│
├── three-mbt ………………… scene graph / math / geometry / materials / lights (pure MoonBit)
│     └── renderers …………… WebGPURenderer: WGSL pipelines, GPU resource cache, frame flow
│             └── wgpu-mbt …… wgpu-native bindings (Vulkan / Metal / D3D12)
│
└── moonbit-libyue ……………… native window & widget tree (GTK / Cocoa / Win32)
        └── handle bridging … Container native handle → X11 window id → GPU surface
```

To embed: place a `Container` in a yue window, get its native widget handle via `@yue.native_handle_view` (on Linux a `GtkWidget*`), convert that to an X11 window id and hand it to `WebGPURenderer::from_xlib`; afterwards call `render(scene, camera)` every frame. Full code in [examples/cube3d](examples/cube3d/main.mbt).

## Quickstart

Prerequisites: the MoonBit native toolchain (`moonc` ≥ 0.10.14, check with `moon version --all`); on Linux, rendering needs a Vulkan driver (lavapipe software rendering works — no GPU required).

```sh
moon new hello3d --user <your-username> --name hello3d
cd hello3d
moon add NoahLiu/three-mbt/math3d
moon add NoahLiu/three-mbt/core
moon add NoahLiu/three-mbt/renderers
```

Set `preferred_target` to `"native"` in `moon.mod`, then declare the packages you use in `cmd/main/moon.pkg`:

```
import {
  "NoahLiu/three-mbt/math3d",
  "NoahLiu/three-mbt/core",
}
```

Build a scene in `cmd/main/main.mbt`:

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
  println("cube vertex count: \{cube.mesh.unwrap().geometry.vertex_count()}")
}
```

`moon run cmd/main` prints `cube vertex count: 24`. Rendering to a window requires a host GUI (surface from a native handle) — see the end-to-end example:

```sh
moon run examples/cube3d   # rotating cube in a yue window, exits after 15 s
```

Geometry generators and lights live in two more packages, add them as needed: `NoahLiu/three-mbt/geometries` (Sphere/Cylinder/Cone/Circle/Torus) and `NoahLiu/three-mbt/lights` (ambient/directional/hemisphere/point/spot).

## Examples

| Example | What it shows | Command |
|---|---|---|
| [cube3d](examples/cube3d/main.mbt) | Rotating cube in a yue window: scene, camera and renderer end to end | `moon run examples/cube3d` |
| [yue_wgpu_window](examples/yue_wgpu_window/main.mbt) | wgpu surface attached to a yue window (integration spike) | `moon run examples/yue_wgpu_window` |

## Capabilities & limitations

- ✅ Math / scene graph / cameras / geometries / material & light data layers, 111 unit tests; cube3d verified on Linux (X11) real hardware and under lavapipe software rendering
- 🟡 The render pipeline is Basic-only (flat color): Lambert/Phong materials and the light data layer are not yet wired into WGSL lighting; textures are data-layer only (no upload/sampling yet)
- 🟡 Surface creation goes through X11 (verified on Linux); Windows/macOS/Wayland window bridging is not yet in place
- ❌ loaders / extras / animation and other modules not started — see the full comparison in [docs/coverage-matrix.md](docs/coverage-matrix.md)

## Contributing

- **Commit gate**: `moon check && moon test` passes with zero errors and zero warnings
- **New modules** follow the existing package layout (math3d / core / lights / geometries / renderers); formulas and edge-case behavior are settled against the [three.js source](https://github.com/mrdoob/three.js), and [docs/coverage-matrix.md](docs/coverage-matrix.md) is updated with each migration

```sh
moon check && moon test   # static check + 111 unit tests
moon run examples/cube3d  # end-to-end smoke (auto-exits after 15 s)
```

## License

`three-mbt` is released under [Apache-2.0](LICENSE). This is an independent implementation: no [three.js](https://github.com/mrdoob/three.js) code (MIT) was copied — its source was used as the design reference for formulas, constants and edge-case behavior. Dependencies: [wgpu-mbt](https://github.com/moonbit-community/wgpu-mbt) (Apache-2.0) and [moonbit-libyue](https://github.com/lb091188/moonbit-libyue) (MIT).
