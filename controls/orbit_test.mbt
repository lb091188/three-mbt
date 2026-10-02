// controls 包黑盒测试:球坐标轨道模型对照 three.js OrbitControls/Spherical。

///|
test "OrbitControls: 初始静止 update 不动相机" {
  let c = @controls.OrbitControls::new()
  let eye = @math3d.Vector3::new(0.0, 0.0, 5.0)
  let new_eye = c.compute_eye(eye)
  debug_inspect(
    (new_eye.x - 0.0).abs() < 0.000001 &&
    (new_eye.y - 0.0).abs() < 0.000001 &&
    (new_eye.z - 5.0).abs() < 0.000001,
    content="true",
  )
}

///|
test "OrbitControls: 水平拖拽只改方位角(theta),半径与高度不变" {
  let c = @controls.OrbitControls::new()
  // 向右拖视口高度的 1/4 → theta -= π/2(three.js _rotateLeft:theta 减)
  c.rotate(120.0, 0.0, 480.0)
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 5.0))
  // +Z 出发 theta:0 → -π/2:eye = (5·sin(-π/2), 0, 5·cos(-π/2)) = (-5,0,~0)
  debug_inspect(
    (eye.x + 5.0).abs() < 0.000001 &&
    eye.y.abs() < 0.000001 &&
    eye.z.abs() < 0.000001,
    content="true",
  )
}

///|
test "OrbitControls: 垂直拖拽只改极角(phi)" {
  let c = @controls.OrbitControls::new()
  // 向下拖视口高度的 1/8 → phi -= π/4(three.js _rotateUp:phi 减):
  // phi π/2 → π/4:eye = (0, 5·cos45°, 5·sin45°)
  c.rotate(0.0, 60.0, 480.0)
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 5.0))
  let s = 5.0 / 2.0.sqrt()
  debug_inspect(
    eye.x.abs() < 0.000001 &&
    (eye.y - s).abs() < 0.000001 &&
    (eye.z - s).abs() < 0.000001,
    content="true",
  )
}

///|
test "OrbitControls: 拖拽后增量被消费(重复 update 不再转动)" {
  let c = @controls.OrbitControls::new()
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  camera.look_at(@math3d.Vector3::new(0.0, 0.0, 5.0), @math3d.Vector3::zero())
  c.rotate(120.0, 0.0, 480.0)
  c.update(camera)
  let x1 = camera.obj.position.x
  c.update(camera) // 无新增量,位置不变
  debug_inspect((camera.obj.position.x - x1).abs() < 0.000001, content="true")
  debug_inspect((x1 + 5.0).abs() < 0.000001, content="true")
}

///|
test "OrbitControls: update 后相机看向 target" {
  let c = @controls.OrbitControls::new()
  c.target = @math3d.Vector3::new(1.0, 0.0, 0.0)
  let camera = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  camera.look_at(@math3d.Vector3::new(1.0, 0.0, 5.0), c.target)
  c.rotate(60.0, 0.0, 480.0) // theta -= π/4
  c.update(camera)
  // 半径 5、theta=-π/4:eye = target + (5·sin(-45°), 0, 5·cos(-45°))
  let s = 5.0 / 2.0.sqrt()
  debug_inspect(
    (camera.obj.position.x - (1.0 - s)).abs() < 0.000001 &&
    camera.obj.position.y.abs() < 0.000001 &&
    (camera.obj.position.z - s).abs() < 0.000001,
    content="true",
  )
  // 视图矩阵作用于 target:视线朝 -Z(target 变换后 z 为负)
  let v = camera.view_matrix().apply_point(c.target)
  debug_inspect(v.z < 0.0, content="true")
}

///|
test "OrbitControls: 极角钳制在开区间 (0, π)" {
  let c = @controls.OrbitControls::new()
  // 巨量向下拖把 phi 拉过 0:被 makeSafe 钳到 0.000001(y→radius)
  c.rotate(0.0, 100000.0, 480.0)
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 5.0))
  debug_inspect(eye.y > 4.999, content="true")
  debug_inspect(eye.y <= 5.0, content="true")
}

///|
test "OrbitControls: 滚轮缩放 0.95 步进(three.js _getZoomScale)" {
  let c = @controls.OrbitControls::new()
  // delta_y=-100:factor = 0.95^(1·|−100·0.01|) = 0.95;dollyIn → 半径 ×0.95
  c.zoom(-100.0)
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 4.0))
  debug_inspect((eye.z - 4.0 * 0.95).abs() < 0.000001, content="true")
  // 向下滚(dollyOut)半径除回 0.95
  c.zoom(100.0)
  let eye2 = c.compute_eye(eye)
  debug_inspect((eye2.z - 4.0).abs() < 0.000001, content="true")
}

///|
test "OrbitControls: 视距钳制 min/max distance" {
  let c = @controls.OrbitControls::new()
  c.min_distance = 2.0
  c.max_distance = 6.0
  c.zoom(-100000.0) // 大幅拉近
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 4.0))
  debug_inspect((eye.z - 2.0).abs() < 0.000001, content="true")
  c.zoom(100000.0) // 大幅拉远
  let eye2 = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 4.0))
  debug_inspect((eye2.z - 6.0).abs() < 0.000001, content="true")
}

///|
test "OrbitControls: rotate_speed 倍率与零高度防御" {
  let c = @controls.OrbitControls::new()
  c.rotate_speed = 2.0
  c.rotate(120.0, 0.0, 480.0) // 2× → theta +π
  let eye = c.compute_eye(@math3d.Vector3::new(0.0, 0.0, 5.0))
  debug_inspect(
    eye.x.abs() < 0.000001 && (eye.z + 5.0).abs() < 0.000001,
    content="true",
  )
  // 视口高度非正:忽略输入
  let c2 = @controls.OrbitControls::new()
  c2.rotate(120.0, 120.0, 0.0)
  debug_inspect(c2.delta_theta == 0.0, content="true")
}
