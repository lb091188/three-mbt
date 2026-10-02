///|
test "Box3 空盒与 set_from_points" {
  let e = @math3d.Box3::empty()
  debug_inspect(e.is_empty(), content="true")
  let b = @math3d.Box3::set_from_points([
    @math3d.Vector3::new(-1.0, 0.0, 2.0),
    @math3d.Vector3::new(3.0, -5.0, 1.0),
  ])
  debug_inspect(b.is_empty(), content="false")
  debug_inspect(b.min.x, content="-1")
  debug_inspect(b.min.y, content="-5")
  debug_inspect(b.min.z, content="1")
  debug_inspect(b.max.x, content="3")
  debug_inspect(b.max.y, content="0")
  debug_inspect(b.max.z, content="2")
  // 空点集仍为空盒(three.js makeEmpty 后无扩展)
  debug_inspect(
    @math3d.Box3::set_from_points([]).is_empty(),
    content="true",
  )
  // 空盒上再 expand 一点后不再空
  debug_inspect(
    e.expand_by_point(@math3d.Vector3::new(1.0, 1.0, 1.0)).is_empty(),
    content="false",
  )
}

///|
test "Box3 set_from_array 与 set_from_center_and_size" {
  let a = @math3d.Box3::set_from_array([
    1.0, 2.0, 3.0, -1.0, -2.0, -3.0, 0.0, 0.0, 0.0,
  ])
  debug_inspect(a.min.x, content="-1")
  debug_inspect(a.max.x, content="1")
  debug_inspect(a.min.z, content="-3")
  debug_inspect(a.max.z, content="3")
  let c = @math3d.Box3::set_from_center_and_size(
    @math3d.Vector3::new(1.0, 1.0, 1.0),
    @math3d.Vector3::new(2.0, 4.0, 2.0),
  )
  debug_inspect(c.min.x, content="0")
  debug_inspect(c.max.x, content="2")
  debug_inspect(c.min.y, content="-1")
  debug_inspect(c.max.y, content="3")
}

///|
test "Box3 get_center/get_size/get_parameter" {
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(0.0, 0.0, 0.0),
    @math3d.Vector3::new(2.0, 2.0, 2.0),
  )
  let center = b.get_center()
  debug_inspect(center.x, content="1")
  debug_inspect(center.y, content="1")
  let size = b.get_size()
  debug_inspect(size.z, content="2")
  // 空盒中心/尺寸为零向量
  let ez = @math3d.Box3::empty().get_size()
  debug_inspect(ez.x == 0.0 && ez.y == 0.0 && ez.z == 0.0, content="true")
  let p = b.get_parameter(@math3d.Vector3::new(0.5, 1.0, 1.5))
  debug_inspect(p.x, content="0.25")
  debug_inspect(p.y, content="0.5")
  debug_inspect(p.z, content="0.75")
}

///|
test "Box3 expand/contains/intersects 族" {
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  let ev = b.expand_by_vector(@math3d.Vector3::new(1.0, 2.0, 3.0))
  debug_inspect(ev.min.x, content="-2")
  debug_inspect(ev.max.z, content="4")
  let es = b.expand_by_scalar(1.0)
  debug_inspect(es.min.y, content="-2")
  debug_inspect(es.max.y, content="2")
  // 收缩(负标量)
  let sh = b.expand_by_scalar(-0.5)
  debug_inspect(sh.min.z, content="-0.5")
  debug_inspect(sh.max.z, content="0.5")
  debug_inspect(b.contains_point(@math3d.Vector3::new(0.0, 0.9, -1.0)), content=(
    #|true
  ))
  debug_inspect(b.contains_point(@math3d.Vector3::new(0.0, 0.0, 1.1)), content=(
    #|false
  ))
  let inner = @math3d.Box3::new(
    @math3d.Vector3::new(-0.5, -0.5, -0.5),
    @math3d.Vector3::new(0.5, 0.5, 0.5),
  )
  debug_inspect(b.contains_box(inner), content="true")
  debug_inspect(inner.contains_box(b), content="false")
  let touch = @math3d.Box3::new(
    @math3d.Vector3::new(1.0, -1.0, -1.0),
    @math3d.Vector3::new(2.0, 1.0, 1.0),
  )
  // 接触算相交
  debug_inspect(b.intersects_box(touch), content="true")
  let apart = @math3d.Box3::new(
    @math3d.Vector3::new(1.5, -1.0, -1.0),
    @math3d.Vector3::new(2.0, 1.0, 1.0),
  )
  debug_inspect(b.intersects_box(apart), content="false")
}

///|
test "Box3 intersect/union" {
  let a = @math3d.Box3::new(
    @math3d.Vector3::new(-2.0, -2.0, -2.0),
    @math3d.Vector3::new(2.0, 2.0, 2.0),
  )
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(0.0, 0.0, 0.0),
    @math3d.Vector3::new(4.0, 4.0, 4.0),
  )
  let i = a.intersect(b)
  debug_inspect(i.min.x, content="0")
  debug_inspect(i.max.x, content="2")
  // 无重叠 → 完全空盒(min=+∞, max=-∞)
  let c = @math3d.Box3::new(
    @math3d.Vector3::new(-3.0, -3.0, -3.0),
    @math3d.Vector3::new(-2.0, -2.0, -2.0),
  )
  let d = @math3d.Box3::new(
    @math3d.Vector3::new(0.0, 0.0, 0.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  debug_inspect(c.intersect(d).is_empty(), content="true")
  let u = a.union(b)
  debug_inspect(u.min.x, content="-2")
  debug_inspect(u.max.x, content="4")
}

///|
test "Box3 clamp_point/distance_to_point/get_bounding_sphere" {
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(0.0, 0.0, 0.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  let cp = b.clamp_point(@math3d.Vector3::new(-1.0, 2.0, 0.5))
  debug_inspect(cp.x, content="0")
  debug_inspect(cp.y, content="1")
  debug_inspect(cp.z, content="0.5")
  debug_inspect(
    b.distance_to_point(@math3d.Vector3::new(2.0, 0.0, 0.0)),
    content="1",
  )
  // 盒内点距离 0
  debug_inspect(
    b.distance_to_point(@math3d.Vector3::new(0.5, 0.5, 0.5)) == 0.0,
    content="true",
  )
  // 单位立方体的包围球半径 = 对角线一半 = sqrt(3)
  let unit = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  let s = unit.get_bounding_sphere()
  debug_inspect(s.radius, content="1.7320508075688772")
  debug_inspect(s.center.x == 0.0 && s.center.z == 0.0, content="true")
  // 空盒 → 空球
  debug_inspect(
    @math3d.Box3::empty().get_bounding_sphere().is_empty(),
    content="true",
  )
}

///|
test "Box3 apply_matrix4/translate" {
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  let t = @math3d.Matrix4::make_translation(5.0, 0.0, 0.0)
  let moved = b.apply_matrix4(t)
  debug_inspect(moved.min.x, content="4")
  debug_inspect(moved.max.x, content="6")
  debug_inspect(moved.min.y, content="-1")
  // 缩放把角点拉远
  let sc = b.apply_matrix4(@math3d.Matrix4::make_scale(2.0, 2.0, 2.0))
  debug_inspect(sc.max.x, content="2")
  debug_inspect(sc.min.z, content="-2")
  // 旋转 90°(绕 Z):立方体对称,包围盒不变
  let rot = b.apply_matrix4(
    @math3d.Matrix4::make_rotation_axis(
      @math3d.Vector3::unit_z(),
      1.5707963267948966,
    ),
  )
  debug_inspect(
    (rot.min.x + 1.0).abs() < 0.0000001 && (rot.max.x - 1.0).abs() < 0.0000001,
    content="true",
  )
  // 空盒变换仍是空盒
  debug_inspect(
    @math3d.Box3::empty().apply_matrix4(t).is_empty(),
    content="true",
  )
  let tr = b.translate(@math3d.Vector3::new(1.0, 2.0, 3.0))
  debug_inspect(tr.min.z, content="2")
  debug_inspect(tr.max.z, content="4")
}

///|
test "Box3 与球/平面相交(three.js 同式)" {
  let b = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  // 球心 (3,0,0) r=1.5:最近点 (1,0,0) 距离平方 4 > 2.25
  debug_inspect(
    b.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 1.5),
    ),
    content="false",
  )
  // r=2 恰好接触(距离平方 4 == 4)
  debug_inspect(
    b.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 2.0),
    ),
    content="true",
  )
  // 平面 z=-1 切过盒体:n=(0,0,1) c=1
  debug_inspect(
    b.intersects_plane(@math3d.Plane::set_components(0.0, 0.0, 1.0, 1.0)),
    content="true",
  )
  // 平面 z=-2 在盒外:c=2
  debug_inspect(
    b.intersects_plane(@math3d.Plane::set_components(0.0, 0.0, 1.0, 2.0)),
    content="false",
  )
  // 负法线平面 z=1:n=(0,0,-1) c=-1
  debug_inspect(
    b.intersects_plane(@math3d.Plane::set_components(0.0, 0.0, -1.0, -1.0)),
    content="true",
  )
}
