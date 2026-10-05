// three.js DirectionalLight 迁移:方向光,方向 = 自身 position 指向 target 位置。

///| 方向光:光线平行(等效无限远光源,模拟日光);方向由 position → target,

///|
/// 节点旋转不参与方向计算
pub(all) struct DirectionalLight {
  /// 光源节点(方向起点;构造默认 (0,1,0),对齐 three.js DEFAULT_UP)
  obj : @core.Object3D
  /// 指向目标(独立节点,默认在原点;要改默认位置需把它一并加入场景)
  mut target : @core.Object3D
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
  /// 是否投射阴影(three.js castShadow;默认 false 与 three.js 一致)
  mut cast_shadow : Bool
  /// 阴影参数(three.js shadow:mapSize/bias/camera;A5)
  mut shadow : @core.DirectionalLightShadow
}

///|
/// 构造(color 默认白,intensity 默认 1;position 默认 (0,1,0),target 默认原点)
pub fn DirectionalLight::new(
  color? : @math3d.Color = @math3d.Color::white(),
  intensity? : Double = 1.0,
) -> DirectionalLight {
  let obj = @core.Object3D::new()
  obj.position = @math3d.Vector3::unit_y()
  obj.update_matrix()
  {
    obj,
    target: @core.Object3D::new(),
    color,
    intensity,
    cast_shadow: false,
    shadow: @core.DirectionalLightShadow::new(),
  }
}

///| 就地拷贝另一盏方向光(target 深拷为同变换新节点,对齐 three.js copy;

///|
/// shadow 参数结构体一并浅拷共享,cast_shadow 逐字段拷)
pub fn DirectionalLight::copy_from(
  self : DirectionalLight,
  other : DirectionalLight,
) -> Unit {
  copy_object3d_into(self.obj, other.obj)
  self.target = copy_object3d(other.target)
  self.color = other.color
  self.intensity = other.intensity
  self.cast_shadow = other.cast_shadow
  self.shadow = other.shadow
}
