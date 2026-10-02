// core 包黑盒测试:场景图与相机。

///|
test "Object3D 层级世界矩阵:父平移+子平移叠加" {
  let parent = @core.Object3D::new()
  parent.position = @math3d.Vector3::new(1.0, 0.0, 0.0)
  let child = @core.Object3D::new()
  child.position = @math3d.Vector3::new(0.0, 1.0, 0.0)
  parent.add(child)
  parent.update_matrix_world(false)
  let wp = child.world_position()
  debug_inspect(wp.x - 1.0 < 0.000001 && wp.y - 1.0 < 0.000001 && wp.z < 0.000001, content="true")
}

///|
test "Object3D compose:T*R*S(先缩放旋转后平移)" {
  let o = @core.Object3D::new()
  o.position = @math3d.Vector3::new(10.0, 0.0, 0.0)
  o.rotation = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    1.5707963267948966,
  )
  o.scale = @math3d.Vector3::new(2.0, 2.0, 2.0)
  o.update_matrix()
  // 局部点 (1,0,0):缩放→(2,0,0),旋转→(0,2,0),平移→(10,2,0)
  let p = o.matrix.apply_point(@math3d.Vector3::unit_x())
  debug_inspect(p.x - 10.0 < 0.000001 && p.y - 2.0 < 0.000001 && p.z < 0.000001, content="true")
}

///|
test "Object3D add/remove 父子互斥" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let c = @core.Object3D::new()
  a.add(b)
  c.add(b) // 应先把 b 从 a 摘除
  debug_inspect(a.children.length(), content="0")
  debug_inspect(c.children.length(), content="1")
  c.remove(b)
  debug_inspect(c.children.length(), content="0")
}

///|
test "Matrix4↔Quaternion 往返" {
  let q1 = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::new(1.0, 1.0, 0.0),
    0.9,
  )
  let q2 = q1.to_matrix4().to_quaternion()
  debug_inspect(q1.dot(q2).abs() > 0.999999, content="true")
}

///|
test "PerspectiveCamera look_at:视图矩阵作用于眼点为零" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  let eye = @math3d.Vector3::new(3.0, 4.0, 5.0)
  cam.look_at(eye, @math3d.Vector3::zero())
  let v = cam.view_matrix()
  let e = v.apply_point(eye)
  debug_inspect(e.x < 0.000001 && e.x > -0.000001, content="true")
  debug_inspect(e.y < 0.000001 && e.y > -0.000001, content="true")
  debug_inspect(e.z < 0.000001 && e.z > -0.000001, content="true")
}

///|
test "PerspectiveCamera 投影:近裁剪点映射到 NDC z≈-1" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.0, 1.0, 100.0)
  cam.look_at(
    @math3d.Vector3::new(0.0, 0.0, 1.0),
    @math3d.Vector3::zero(),
  )
  let v = cam.view_matrix()
  let p = cam.projection_matrix.apply_point(
    v.apply_point(@math3d.Vector3::zero()),
  )
  debug_inspect(p.z > -1.000001 && p.z < -0.999999, content="true")
}

///|
test "Scene 基本结构" {
  let s = @core.Scene::new()
  let o = @core.Object3D::new()
  s.add(o)
  s.background = Some(@math3d.Color::from_hex("#101010").unwrap())
  s.update_matrix_world()
  debug_inspect(s.root.children.length(), content="1")
  debug_inspect(s.background.unwrap().to_hex() == "#101010", content="true")
}
