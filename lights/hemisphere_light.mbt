// three.js HemisphereLight 迁移:半球光,天空色到地面色渐变,不投影。

///| 半球光:位于场景正上方,自天空色向地面色渐变照明
pub(all) struct HemisphereLight {
  /// 光源节点(构造默认 (0,1,0),对齐 three.js DEFAULT_UP;照明方向固定
  /// 天空→地面,不随节点旋转)
  obj : @core.Object3D
  /// 天空色(统一 color 字段)
  mut color : @math3d.Color
  /// 地面色
  mut ground_color : @math3d.Color
  /// 强度
  mut intensity : Double
}

///| 构造(sky_color/ground_color 默认白,intensity 默认 1)
pub fn HemisphereLight::new(
  sky_color~ : @math3d.Color = @math3d.Color::white(),
  ground_color~ : @math3d.Color = @math3d.Color::white(),
  intensity~ : Double = 1.0,
) -> HemisphereLight {
  let obj = @core.Object3D::new()
  obj.position = @math3d.Vector3::unit_y()
  obj.update_matrix()
  { obj, color: sky_color, ground_color, intensity }
}

///| 就地拷贝另一盏半球光(含 ground_color,对齐 three.js copy 字段集)
pub fn HemisphereLight::copy_from(
  self : HemisphereLight,
  other : HemisphereLight,
) -> Unit {
  copy_object3d_into(self.obj, other.obj)
  self.color = other.color
  self.ground_color = other.ground_color
  self.intensity = other.intensity
}
