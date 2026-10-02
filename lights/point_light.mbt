// three.js PointLight 迁移:点光源,自一点向所有方向发光(灯泡),distance/decay 衰减。

///| 点光源:位置即发光点,向所有方向均匀发光
pub(all) struct PointLight {
  /// 光源节点(position 即光源位置,默认原点)
  obj : @core.Object3D
  /// 光色
  mut color : @math3d.Color
  /// 强度(单位坎德拉 cd)
  mut intensity : Double
  /// 最大照射距离;0=不限制(distance=0 时按平方反比衰减到无穷远)
  mut distance : Double
  /// 沿距离的衰减指数(物理正确渲染保持默认 2)
  mut decay : Double
}

///| 构造(color 默认白,intensity 默认 1,distance 默认 0,decay 默认 2)
pub fn PointLight::new(
  color~ : @math3d.Color = @math3d.Color::white(),
  intensity~ : Double = 1.0,
  distance~ : Double = 0.0,
  decay~ : Double = 2.0,
) -> PointLight {
  { obj: @core.Object3D::new(), color, intensity, distance, decay }
}

///| 光通量功率(流明 lm):各向同性光源 lm = 4π·cd,由强度换算
pub fn PointLight::power(self : PointLight) -> Double {
  self.intensity * 4.0 * @math.PI
}

///| 按功率(流明)设强度:cd = lm / (4π)
pub fn PointLight::set_power(self : PointLight, power : Double) -> Unit {
  self.intensity = power / (4.0 * @math.PI)
}

///| 就地拷贝另一盘点光源(含 distance/decay,对齐 three.js copy 字段集)
pub fn PointLight::copy_from(
  self : PointLight,
  other : PointLight,
) -> Unit {
  copy_object3d_into(self.obj, other.obj)
  self.color = other.color
  self.intensity = other.intensity
  self.distance = other.distance
  self.decay = other.decay
}
