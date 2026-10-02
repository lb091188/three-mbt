// three.js SpotLight 迁移:聚光灯,自一点沿锥形向 target 方向发光。

///| 聚光灯:自一点沿一个方向、按锥角发散(方向 = position → target)
pub(all) struct SpotLight {
  /// 光源节点(方向起点;构造默认 (0,1,0),对齐 three.js DEFAULT_UP)
  obj : @core.Object3D
  /// 指向目标(独立节点,默认在原点;要改默认位置需把它一并加入场景)
  mut target : @core.Object3D
  /// 光色
  mut color : @math3d.Color
  /// 强度(单位坎德拉 cd)
  mut intensity : Double
  /// 最大照射距离;0=不限制
  mut distance : Double
  /// 光锥张角(弧度,自方向轴向外量的最大发散角,上界 π/2;存储不钳制)
  mut angle : Double
  /// 半影比例:光锥边缘衰减的占比,取值 0..1(存储不钳制)
  mut penumbra : Double
  /// 沿距离的衰减指数(物理正确渲染保持默认 2)
  mut decay : Double
}

///| 构造(color 默认白,intensity 默认 1,distance 默认 0,angle 默认 π/3,
///| penumbra 默认 0,decay 默认 2;position 默认 (0,1,0),target 默认原点)
pub fn SpotLight::new(
  color~ : @math3d.Color = @math3d.Color::white(),
  intensity~ : Double = 1.0,
  distance~ : Double = 0.0,
  angle~ : Double = @math.PI / 3.0,
  penumbra~ : Double = 0.0,
  decay~ : Double = 2.0,
) -> SpotLight {
  let obj = @core.Object3D::new()
  obj.position = @math3d.Vector3::unit_y()
  obj.update_matrix()
  { obj, target: @core.Object3D::new(), color, intensity, distance, angle, penumbra, decay }
}

///| 光通量功率(流明 lm):聚光灯按约定 lm = π·cd,由强度换算
pub fn SpotLight::power(self : SpotLight) -> Double {
  self.intensity * @math.PI
}

///| 按功率(流明)设强度:cd = lm / π
pub fn SpotLight::set_power(self : SpotLight, power : Double) -> Unit {
  self.intensity = power / @math.PI
}

///| 就地拷贝另一盏聚光灯(含 distance/angle/penumbra/decay,target 深拷,
///| 对齐 three.js copy 字段集)
pub fn SpotLight::copy_from(self : SpotLight, other : SpotLight) -> Unit {
  copy_object3d_into(self.obj, other.obj)
  self.target = copy_object3d(other.target)
  self.color = other.color
  self.intensity = other.intensity
  self.distance = other.distance
  self.angle = other.angle
  self.penumbra = other.penumbra
  self.decay = other.decay
}
