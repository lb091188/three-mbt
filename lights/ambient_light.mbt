// three.js AmbientLight 迁移:全局等量环境光,无方向、不可投影。

///| 环境光:对所有物体等量照明,color*intensity 统一承载亮度
pub(all) struct AmbientLight {
  /// 光源节点(挂场景用;环境光与位置/方向无关)
  obj : @core.Object3D
  /// 光色
  mut color : @math3d.Color
  /// 强度
  mut intensity : Double
}

///| 构造(color 默认白 0xffffff,intensity 默认 1)
pub fn AmbientLight::new(
  color~ : @math3d.Color = @math3d.Color::white(),
  intensity~ : Double = 1.0,
) -> AmbientLight {
  { obj: @core.Object3D::new(), color, intensity }
}

///| 就地拷贝另一盏环境光(节点状态+光色+强度,对齐 three.js copy 字段集)
pub fn AmbientLight::copy_from(
  self : AmbientLight,
  other : AmbientLight,
) -> Unit {
  copy_object3d_into(self.obj, other.obj)
  self.color = other.color
  self.intensity = other.intensity
}
