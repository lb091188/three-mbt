// three.js Scene 迁移:场景根 + 背景色 + 光源集合。

///| 环境光的世界空间参数(渲染层消费;经 renderers 包的挂接函数写入)
pub(all) struct SceneAmbientLight {
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
}

///| 方向光的世界空间参数
pub(all) struct SceneDirectionalLight {
  /// 入射方向:被照表面指向光源的单位向量(three.js 方向光 uniform 同约定)
  mut direction : @math3d.Vector3
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
}

///| 点光源的世界空间参数
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

///| 场景光源集合(每类至多一盏;光照管线的 uniform 数据源)
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
///| 上半球天空色、下半球地面色,按世界法线 y 分量混合)
pub(all) struct SceneHemisphereLight {
  /// 天空色(含强度预乘)
  mut sky_color : @math3d.Color
  /// 地面色(含强度预乘)
  mut ground_color : @math3d.Color
}

///| 构造空光源集合
pub fn SceneLights::empty() -> SceneLights {
  { ambient: None, directional: None, point: None, hemisphere: None }
}

///| 场景
pub(all) struct Scene {
  /// 场景根节点(往这上面 add)
  root : Object3D
  /// 背景色(None=渲染器默认清屏色)
  mut background : @math3d.Color?
  /// 光源集合(经 renderers 包的挂接函数从 lights 包光源写入)
  mut lights : SceneLights
}

///| 构造空场景
pub fn Scene::new() -> Scene {
  {
    root: Object3D::new(),
    background: None,
    lights: SceneLights::empty(),
  }
}

///| 挂子节点到场景
pub fn Scene::add(self : Scene, child : Object3D) -> Unit {
  self.root.add(child)
}

///| 更新整棵场景的世界矩阵(渲染前调用)
pub fn Scene::update_matrix_world(self : Scene) -> Unit {
  self.root.update_matrix_world(false)
}
