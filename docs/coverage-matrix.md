# three.js → three-mbt 迁移覆盖矩阵

对照基准:[threejs-ref](https://github.com/mrdoob/three.js)(three.js **r186**,0.186.0)`src/` 模块清单,逐模块标注迁移状态与差距。

- ✅ 已迁移 · 🟡 部分迁移 · ❌ 未开始
- 「位置」列指 three-mbt 中的实现包;three.js 的 cameras/materials/textures 在本库按数据层归入 `core` 包,几何生成器与光源独立成包
- 每完成一批迁移,同步更新本表

| 模块 | 位置 | 状态 | 已迁移 | 差距 |
|---|---|---|---|---|
| math | `math3d` | 🟡 | Vector2/3/4、Matrix3/4、Quaternion、Euler、Color、Box3、Sphere、Plane、Ray、Frustum、MathUtils(13/24 类) | 缺 Box2、Matrix2、Cylindrical、Spherical、Line3、Triangle、SphericalHarmonics3、Interpolant 插值族与 ColorManagement |
| core | `core` | 🟡 | Object3D(层级/世界矩阵/traverse)、Scene、BufferGeometry(位置/法线/UV/索引) | 缺 Raycaster、EventDispatcher、Layers、Clock/Timer、RenderTarget 族、Uniform(s)Group、Interleaved/Instanced buffer 族与 BufferAttribute 的 typed-array 视图 |
| cameras | `core` | 🟡 | PerspectiveCamera、OrthographicCamera(投影按 WebGPU 深度域 z∈[0,1]) | 缺 ArrayCamera、CubeCamera、StereoCamera 与 zoom/view offset 参数 |
| lights | `lights` | 🟡 | Ambient/Directional/Hemisphere/Point/Spot 五种光源数据层 | 缺 RectAreaLight、LightProbe 与各类 Shadow;光源尚未接入渲染管线(WGSL 光照未实现) |
| materials | `core` | 🟡 | Basic/Lambert/Phong 三种材质数据层 | 缺 Standard/Physical/Toon/Matcap/Normal/Depth/Shader/Line/Points/Sprite 等十余种;渲染器当前仅绘制 Basic |
| geometries | `core` + `geometries` | 🟡 | Box、Plane(core);Sphere、Cylinder、Cone、Circle、Torus(geometries 包),7/22 | 缺 Capsule、Polyhedron 族(四面/八面/十二面/二十面)、Ring、Lathe、Shape/Extrude、TorusKnot、Tube、Edges、Wireframe |
| textures | `core` | 🟡 | Texture 数据层:环绕/过滤/色彩空间枚举、UV 平铺与偏移 | 缺图像数据引用与 mipmap、GPU 上传采样,以及 DataTexture/CubeTexture/CompressedTexture 等具体纹理类 |
| loaders | — | ❌ | — | 资源加载全缺(File/图片/GLTF 等 16 文件),文件系统与图像解码链路待定 |
| renderers | `renderers` | 🟡 | WebGPURenderer:wgpu surface、WGSL Basic 管线、逐 mesh GPU 资源缓存、深度附着、resize | 缺光照/阴影/纹理采样管线、多材质管线分发、render target 与后处理;WebGLRenderer 与 webxr 不在迁移范围 |
| extras | — | ❌ | — | Earcut 三角剖分、curves 曲线族、Controls(轨道控制等)、PMREMGenerator 全缺 |

## 对照清单外的上游模块

three.js `src/` 还有以下模块,不在上表十个对照项内,状态一并记录:

| 模块 | 状态 | 说明 |
|---|---|---|
| scenes | 🟡 | Scene 已迁(core 包);Fog/FogExp2 未迁 |
| objects | 🟡 | Mesh 已迁(core 包);Group/Line/Points/Sprite/InstancedMesh/骨骼蒙皮(Skeleton/SkinnedMesh)等未迁 |
| animation | ❌ | AnimationMixer/AnimationClip/关键帧轨道全缺 |
| helpers | ❌ | 坐标轴/网格等辅助显示对象未迁 |
| nodes | ❌ | TSL 节点材质体系未迁(远期评估) |
| audio | ❌ | 位置音频未迁,依赖宿主应用的音频方案 |
| constants | 🟡 | 常数以枚举形式随对应模块迁移(如 Wrapping/TextureFilter/ColorSpace),未集中成模块 |
