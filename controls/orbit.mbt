// 轨道相机控制(纯逻辑):球坐标模型对照 three.js
// OrbitControls(examples/jsm/controls/OrbitControls.js)与 Spherical
// (radius;phi 为从 +Y 轴起的极角;theta 为绕 Y 轴、从 +Z 起的方位角)。
// 惯性(damping)与平移(pan)未迁移:增量即时应用。
//
// 不监听任何事件,由宿主喂数据,典型用法:
//

///| ```moonbit

///| let controls = @controls.OrbitControls::new()

///| let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)

///| camera.look_at(@math3d.Vector3::new(0.0, 1.0, 3.0), controls.target)

///| // 拖拽:鼠标事件里把像素增量喂给 rotate(viewport_height 用视口高度,

///| // 对照 three.js「拖满一个视口高度 = 旋转一整圈」的换算)

///| controls.rotate(dx_pixels, dy_pixels, view_height)

///| controls.update(camera) // 应用并写回相机位置与朝向

///| // 滚轮:controls.zoom(wheel_delta_y)(正=向下滚=拉远)

///| ```
//
// update 从相机当前位置反推球坐标再应用增量(对照 OrbitControls.update
// 的 offset→spherical→增量→回写流程),所以相机位置也可被外部直接改动。

///|
/// 轨道相机控制器(纯逻辑,不监听事件)
pub(all) struct OrbitControls {
  /// 轨道中心(相机绕它转,同时是 look_at 目标)
  mut target : @math3d.Vector3
  /// 极角下限弧度(three.js minPolarAngle,默认 0)
  mut min_polar_angle : Double
  /// 极角上限弧度(three.js maxPolarAngle,默认 π)
  mut max_polar_angle : Double
  /// 最小视距(three.js minDistance,默认 0)
  mut min_distance : Double
  /// 最大视距(three.js maxDistance,默认无限制;≤0 视为不设限)
  mut max_distance : Double
  /// 旋转速度倍率(three.js rotateSpeed,默认 1)
  mut rotate_speed : Double
  /// 缩放速度倍率(three.js zoomSpeed,默认 1)
  mut zoom_speed : Double
  // 待应用增量(rotate/zoom 累积,update/compute_eye 应用后清零)
  mut delta_theta : Double
  mut delta_phi : Double
  mut dolly_scale : Double
}

///|
/// 构造:参数取 three.js OrbitControls 默认值
pub fn OrbitControls::new() -> OrbitControls {
  {
    target: @math3d.Vector3::zero(),
    min_polar_angle: 0.0,
    max_polar_angle: @math.PI,
    min_distance: 0.0,
    max_distance: 0.0,
    rotate_speed: 1.0,
    zoom_speed: 1.0,
    delta_theta: 0.0,
    delta_phi: 0.0,
    dolly_scale: 1.0,
  }
}

///| 喂入拖拽增量(像素;对照 _handleMouseMoveRotate +

///| _rotateLeft/_rotateUp:theta/phi 减去 2π·delta·rotateSpeed/视口高度,

///|
/// 即拖满一个视口高度旋转一整圈)
pub fn OrbitControls::rotate(
  self : OrbitControls,
  dx_pixels : Double,
  dy_pixels : Double,
  viewport_height : Double,
) -> Unit {
  if viewport_height <= 0.0 {
    return
  }
  self.delta_theta = self.delta_theta -
    2.0 * @math.PI * dx_pixels * self.rotate_speed / viewport_height
  self.delta_phi = self.delta_phi -
    2.0 * @math.PI * dy_pixels * self.rotate_speed / viewport_height
}

///| 喂入滚轮增量(对照 onMouseWheel + _getZoomScale + _dollyIn/_dollyOut:

///| 缩放系数 = 0.95^(zoomSpeed·|delta·0.01|);delta_y<0 向上滚拉近、

///|
/// >0 向下滚拉远)
pub fn OrbitControls::zoom(
  self : OrbitControls,
  wheel_delta_y : Double,
) -> Unit {
  let normalized = (wheel_delta_y * 0.01).abs()
  let factor = @math.pow(0.95, self.zoom_speed * normalized)
  if wheel_delta_y < 0.0 {
    self.dolly_scale = self.dolly_scale * factor
  } else if wheel_delta_y > 0.0 {
    self.dolly_scale = self.dolly_scale / factor
  }
}

///| 应用累积增量并驱动相机:更新相机眼点位置,重新看向 target。

///|
/// 每帧(或每个拖拽事件)调用一次;应用后清空增量
pub fn OrbitControls::update(
  self : OrbitControls,
  camera : @core.PerspectiveCamera,
) -> Unit {
  let eye = self.compute_eye(camera.obj.position)
  camera.look_at(eye, self.target)
}

///| update 的纯计算部分:给定相机当前位置,应用累积增量返回新眼点

///|
/// (应用后清空增量;不依赖相机对象,便于脱离渲染做逻辑测试)
pub fn OrbitControls::compute_eye(
  self : OrbitControls,
  position : @math3d.Vector3,
) -> @math3d.Vector3 {
  let offset = position.sub(self.target)
  // Spherical.setFromVector3:radius/theta=atan2(x,z)/phi=acos(clamp(y/r))
  let radius = offset.length()
  let mut theta = 0.0
  let mut phi = 0.0
  if radius != 0.0 {
    theta = @math.atan2(offset.x, offset.z)
    phi = @math.acos((offset.y / radius).clamp(min=-1.0, max=1.0))
  }
  // 应用旋转增量(无 damping,即时全量)
  theta = theta + self.delta_theta
  phi = phi + self.delta_phi
  // 极角限位(three.js min/maxPolarAngle)+ makeSafe(0.000001, π-0.000001)
  phi = phi.clamp(min=self.min_polar_angle, max=self.max_polar_angle)
  phi = phi.clamp(min=0.000001, max=@math.PI - 0.000001)
  // 半径缩放 + 视距限位(three.js minDistance/maxDistance;≤0 不设限)
  let mut new_radius = radius * self.dolly_scale
  if new_radius < self.min_distance {
    new_radius = self.min_distance
  }
  if self.max_distance > 0.0 && new_radius > self.max_distance {
    new_radius = self.max_distance
  }
  // 回笛卡尔(Spherical→Vector3:three.js setFromSpherical 同式)
  let sin_phi = @math.sin(phi)
  let new_offset = @math3d.Vector3::new(
    new_radius * sin_phi * @math.sin(theta),
    new_radius * @math.cos(phi),
    new_radius * sin_phi * @math.cos(theta),
  )
  // 增量消费完毕清零(对照 update() 末尾 if (!enableDamping) 分支)
  self.delta_theta = 0.0
  self.delta_phi = 0.0
  self.dolly_scale = 1.0
  self.target.add(new_offset)
}

///|
/// 任务侧命名别名:OrbitCamera 即 OrbitControls(绕点环绕 + 滚轮缩放,
/// three.js OrbitControls/Spherical 同式;宿主喂像素拖拽与滚轮增量)。
pub type OrbitCamera = OrbitControls
