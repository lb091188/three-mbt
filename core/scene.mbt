// three.js Scene 迁移:场景根 + 背景色 + 光源集合。

///|
/// 环境光的世界空间参数(渲染层消费;经 renderers 包的挂接函数写入)
pub(all) struct SceneAmbientLight {
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
}

///| 方向光阴影相机的正交视锥(three.js DirectionalLightShadow.camera 的

///|
/// left/right/top/bottom/near/far 六参数)
pub(all) struct ShadowCamera {
  mut left : Double
  mut right : Double
  mut top : Double
  mut bottom : Double
  /// 近裁剪面(沿光线反向、自光源起算)
  mut near : Double
  /// 远裁剪面
  mut far : Double
}

///|
/// 方向光阴影参数(three.js light.shadow:mapSize/bias/camera;A5)
pub(all) struct DirectionalLightShadow {
  /// 阴影贴图边长(方形;three.js shadow.mapSize,默认 512)
  mut map_size : Int
  /// 深度偏移(three.js shadow.bias;本仓约定正值直接从受照片元深度中
  /// 减去——正值→更易判定受照,用于压自阴影 acne)
  mut bias : Double
  /// 阴影相机正交视锥(three.js 默认 -5/5/5/-5/0.5/500)
  mut camera : ShadowCamera
}

///|
/// 构造默认阴影参数(three.js DirectionalLightShadow 默认值)
pub fn DirectionalLightShadow::new() -> DirectionalLightShadow {
  {
    map_size: 512,
    bias: 0.0,
    camera: {
      left: -5.0,
      right: 5.0,
      top: 5.0,
      bottom: -5.0,
      near: 0.5,
      far: 500.0,
    },
  }
}

///|
/// 方向光的世界空间参数
pub(all) struct SceneDirectionalLight {
  /// 入射方向:被照表面指向光源的单位向量(three.js 方向光 uniform 同约定)
  mut direction : @math3d.Vector3
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
  /// 光源世界位置(阴影相机视点;attach 时从光源节点写入;A5)
  mut position : @math3d.Vector3
  /// 是否投射阴影(three.js castShadow;A5)
  mut cast_shadow : Bool
  /// 阴影参数(three.js shadow;cast_shadow=true 时渲染层消费;A5)
  mut shadow : DirectionalLightShadow
}

///|
/// 点光源的世界空间参数
pub(all) struct ScenePointLight {
  /// 世界空间发光位置
  mut position : @math3d.Vector3
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
  /// 最大照射距离;0=不限制
  mut distance : Double
  /// 衰减指数(默认 2)
  mut decay : Double
}

///|
/// 雾(A6):Exp2 指数雾 / Linear 线性雾(three.js Fog/FogExp2)
pub(all) struct Fog {
  /// 0=Linear(near/far)、1=Exp2(density)
  kind : Int
  /// 雾色
  mut color : @math3d.Color
  /// 线性雾起点(near)
  mut near : Double
  /// 线性雾终点(far)
  mut far : Double
  /// 指数雾密度(density)
  mut density : Double
}

///|
/// 指数雾(FogExp2)
pub fn Fog::exp2(color : @math3d.Color, density : Double) -> Fog {
  { kind: 1, color, near: 1.0, far: 1000.0, density, }
}

///|
/// 线性雾(Fog)
pub fn Fog::linear(color : @math3d.Color, near : Double, far : Double) -> Fog {
  { kind: 0, color, near, far, density: 0.0, }
}

///|
/// 场景光源集合(每类至多一盏;光照管线的 uniform 数据源)
pub(all) struct SceneLights {
  /// 环境光(None=无环境光贡献)
  mut ambient : SceneAmbientLight?
  /// 方向光(None=无方向光)
  mut directional : SceneDirectionalLight?
  /// 点光源(None=无点光)
  mut point : ScenePointLight?
  /// 半球光(None=无;天空/地面双色按法线混合,A4)
  mut hemisphere : SceneHemisphereLight?
}

///| 半球光的世界空间参数(three.js HemisphereLight 照明约定:

///|
/// 上半球天空色、下半球地面色,按世界法线 y 分量混合)
pub(all) struct SceneHemisphereLight {
  /// 天空色(含强度预乘)
  mut sky_color : @math3d.Color
  /// 地面色(含强度预乘)
  mut ground_color : @math3d.Color
}

///|
/// 构造空光源集合
pub fn SceneLights::empty() -> SceneLights {
  { ambient: None, directional: None, point: None, hemisphere: None, }
}

///|
/// 场景
pub(all) struct Scene {
  /// 场景根节点(往这上面 add)
  root : Object3D
  /// 背景色(None=渲染器默认清屏色)
  mut background : @math3d.Color?
  /// 光源集合(经 renderers 包的挂接函数从 lights 包光源写入)
  mut lights : SceneLights
  /// 场景雾(None=无雾;A6)
  mut fog : Fog?
}

///|
/// 构造空场景
pub fn Scene::new() -> Scene {
  {
    root: Object3D::new(),
    background: None,
    lights: SceneLights::empty(),
    fog: None,
  }
}

///|
/// 挂子节点到场景
pub fn Scene::add(self : Scene, child : Object3D) -> Unit {
  self.root.add(child)
}

///|
/// 更新整棵场景的世界矩阵(渲染前调用)
pub fn Scene::update_matrix_world(self : Scene) -> Unit {
  self.root.update_matrix_world(false)
}
