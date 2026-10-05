// 追逐相机(纯逻辑):跟随目标平滑移动 + 平滑注视。
// 数学:帧率无关的指数平滑 —— 每帧插值系数 = 1 - exp(-dt/τ)(τ 为时间
// 常数,一个 τ 内追完剩余距离的 63.2%,与 three.js 的 damping 思路一致但
// 按物理时间而非帧数,掉帧不改变收敛速度)。首帧自动对齐目标(primed),
// 避免从原点甩镜飞入。
//
// 不监听任何事件,由宿主每帧喂数:
// ```moonbit
// let chase = @controls.ChaseCamera::new()
// // 每帧(目标位置 + 朝向 + 帧时长):
// chase.update(camera, target_pos, heading, dt)
// ```
// heading 为目标绕 Y 轴朝向(弧度):offset 在 heading=0 时位于目标
// +Z 方向(正后方),heading 增大按右手系绕 Y 旋转
// (x' = x·cosθ + z·sinθ, z' = -x·sinθ + z·cosθ,three.js
// Vector3.applyAxisAngle(Y, θ) 同式)。

///|
/// 追逐相机控制器(纯逻辑,不监听事件)
pub(all) struct ChaseCamera {
  /// 期望眼点相对目标的偏移(heading=0 时 +Z 为正后方;默认高 4 后 8)
  mut offset : @math3d.Vector3
  /// 位置平滑时间常数(秒;≤0 视为立即贴住)
  mut smooth_tau : Double
  /// 注视点平滑时间常数(秒;≤0 视为立即贴住)
  mut look_tau : Double
  /// 注视点相对目标的高度(看车顶而不是原点)
  mut look_height : Double
  /// 当前平滑眼点(update 内部维护;首帧对齐目标)
  mut cur_eye : @math3d.Vector3
  /// 当前平滑注视点
  mut cur_look : @math3d.Vector3
  /// 是否已对齐过首帧
  mut primed : Bool
}

///|
/// 构造:offset (0,4,8)、位置 τ=0.25s、注视 τ=0.12s、注视高度 1.2。
pub fn ChaseCamera::new() -> ChaseCamera {
  {
    offset: @math3d.Vector3::new(0.0, 4.0, 8.0),
    smooth_tau: 0.25,
    look_tau: 0.12,
    look_height: 1.2,
    cur_eye: @math3d.Vector3::zero(),
    cur_look: @math3d.Vector3::zero(),
    primed: false,
  }
}

///|
/// 帧率无关指数平滑系数:1 - exp(-dt/τ)。τ≤0 视为立即贴住(1);
/// dt≤0 无时间流逝(0)。
pub fn ChaseCamera::smooth_factor(dt : Double, tau : Double) -> Double {
  if tau <= 0.0 {
    return 1.0
  }
  if dt <= 0.0 {
    return 0.0
  }
  1.0 - @math.exp(-dt / tau)
}

///|
/// 绕 Y 轴旋转向量(three.js applyAxisAngle(Y, θ) 同式)。
pub fn ChaseCamera::rotate_y(
  v : @math3d.Vector3,
  angle : Double,
) -> @math3d.Vector3 {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  @math3d.Vector3::new(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
}

///|
/// 给定目标位置与朝向的期望眼点(纯计算,便于脱离渲染测试)。
pub fn ChaseCamera::desired_eye(
  self : ChaseCamera,
  target_pos : @math3d.Vector3,
  heading : Double,
) -> @math3d.Vector3 {
  target_pos.add(ChaseCamera::rotate_y(self.offset, heading))
}

///|
/// 每帧驱动:平滑追赶期望眼点与注视点,并写回相机(位置 + look_at)。
/// dt 为帧时长(秒);首帧直接对齐目标,后续按 τ 指数平滑。
pub fn ChaseCamera::update(
  self : ChaseCamera,
  camera : @core.PerspectiveCamera,
  target_pos : @math3d.Vector3,
  heading : Double,
  dt : Double,
) -> Unit {
  let desired_eye = self.desired_eye(target_pos, heading)
  let desired_look = @math3d.Vector3::new(
    target_pos.x,
    target_pos.y + self.look_height,
    target_pos.z,
  )
  if !self.primed {
    self.cur_eye = desired_eye
    self.cur_look = desired_look
    self.primed = true
  } else {
    self.cur_eye = self.cur_eye.lerp(
      desired_eye,
      ChaseCamera::smooth_factor(dt, self.smooth_tau),
    )
    self.cur_look = self.cur_look.lerp(
      desired_look,
      ChaseCamera::smooth_factor(dt, self.look_tau),
    )
  }
  camera.look_at(self.cur_eye, self.cur_look)
}
