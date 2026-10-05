// controls 包 ChaseCamera 黑盒测试:指数平滑与朝向旋转的数学。

///|
test "ChaseCamera::smooth_factor: τ≤0 立即贴住,dt≤0 不动,dt=τ 为 63.2%" {
  assert_true(ChaseCamera::smooth_factor(1.0, 0.0) == 1.0)
  assert_true(ChaseCamera::smooth_factor(0.0, 0.25) == 0.0)
  // 一个时间常数后追完剩余距离的 1 - 1/e
  let got = ChaseCamera::smooth_factor(0.25, 0.25)
  let want = 1.0 - @math.exp(-1.0)
  assert_true((got - want).abs() < 0.000000000001)
}

///|
test "ChaseCamera::desired_eye: heading=0 时 offset 原样加在目标上" {
  let c = ChaseCamera::new()
  let eye = c.desired_eye(@math3d.Vector3::new(10.0, 0.0, -5.0), 0.0)
  // (10,0,-5) + (0,4,8) = (10,4,3)
  assert_true(
    (eye.x - 10.0).abs() < 0.000000000001 &&
    (eye.y - 4.0).abs() < 0.000000000001 &&
    (eye.z - 3.0).abs() < 0.000000000001,
  )
}

///|
test "ChaseCamera::desired_eye: heading=+π/2 把 +Z 偏移转到 +X" {
  let c = ChaseCamera::new()
  let eye = c.desired_eye(@math3d.Vector3::zero(), @math.PI / 2.0)
  // (0,4,8) 绕 Y 转 90°:x' = 8·sin90° = 8,z' = 8·cos90° = 0
  assert_true(
    (eye.x - 8.0).abs() < 0.000000001 &&
    (eye.y - 4.0).abs() < 0.000000000001 &&
    eye.z.abs() < 0.000000001,
  )
}

///|
test "ChaseCamera::update: 首帧直接对齐期望眼点(不甩镜)" {
  let c = ChaseCamera::new()
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  let target = @math3d.Vector3::new(3.0, 0.0, -2.0)
  c.update(camera, target, 0.0, 0.016)
  let eye = camera.obj.position
  assert_true(
    (eye.x - 3.0).abs() < 0.000000000001 &&
    (eye.y - 4.0).abs() < 0.000000000001 &&
    (eye.z - 6.0).abs() < 0.000000000001,
  )
}

///|
test "ChaseCamera::update: 一个 τ 后剩余距离恰为 e^-1(帧率无关平滑)" {
  let c = ChaseCamera::new()
  c.offset = @math3d.Vector3::new(0.0, 0.0, 8.0)
  c.smooth_tau = 0.25
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  // 首帧对齐:eye=(0,0,8),期望眼点 (0,0,8)
  c.update(camera, @math3d.Vector3::zero(), 0.0, 0.016)
  // 目标朝向转 90°:期望眼点跳到 (8,0,0)。lerp 沿弦线走,初始弦距
  // 8√2,一个 τ 后剩余距离 = 8√2·e^-1(平滑按比例消距离,与方向无关)
  c.update(camera, @math3d.Vector3::zero(), @math.PI / 2.0, 0.25)
  let eye = camera.obj.position
  let dx = eye.x - 8.0
  let dz = eye.z
  let dist = (dx * dx + dz * dz).sqrt()
  let want = 8.0 * 2.0.sqrt() * @math.exp(-1.0)
  assert_true((dist - want).abs() < 0.000001)
}

///|
test "ChaseCamera::update: 常值目标下指数收敛(500 帧后误差 < 0.000001)" {
  let c = ChaseCamera::new()
  c.offset = @math3d.Vector3::new(0.0, 0.0, 8.0)
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  c.update(camera, @math3d.Vector3::zero(), 0.0, 0.016)
  let heading = @math.PI / 3.0
  for _i in 0..<500 {
    c.update(camera, @math3d.Vector3::zero(), heading, 1.0 / 60.0)
  }
  let eye = camera.obj.position
  let want = c.desired_eye(@math3d.Vector3::zero(), heading)
  assert_true(
    (eye.x - want.x).abs() < 0.000001 &&
    (eye.y - want.y).abs() < 0.000001 &&
    (eye.z - want.z).abs() < 0.000001,
  )
}

///|
test "ChaseCamera::update: 注视点平滑趋近目标上方 look_height" {
  let c = ChaseCamera::new()
  c.smooth_tau = 0.1
  c.look_tau = 0.1
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  c.update(camera, @math3d.Vector3::new(0.0, 0.0, 0.0), 0.0, 0.016)
  // 注视点目标 (0, 1.2, 0),首帧对齐;再次 update(dt=0)不移动
  c.update(camera, @math3d.Vector3::new(0.0, 0.0, 0.0), 0.0, 0.0)
  assert_true(
    (c.cur_look.y - 1.2).abs() < 0.000000000001 &&
    (c.cur_look.x - 0.0).abs() < 0.000000000001,
  )
}

///|
test "OrbitCamera 别名即 OrbitControls(方法透传,拖拽与缩放可用)" {
  let c : @controls.OrbitCamera = @controls.OrbitCamera::new()
  c.rotate(10.0, 0.0, 100.0)
  assert_true(c.delta_theta.abs() > 0.0)
  c.zoom(-100.0)
  // zoom(-100) → 0.95^1:dolly 后 5.0 → 4.75
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 5.0))
  assert_true((eye.length() - 4.75).abs() < 0.000000001)
}
