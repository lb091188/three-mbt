///|
test "Plane 构造族:set_from_normal_and_coplanar_point / coplanar_points" {
  // z=0 平面:法线 (0,0,1),过原点
  let p = @math3d.Plane::set_from_normal_and_coplanar_point(
    @math3d.Vector3::unit_z(),
    @math3d.Vector3::zero(),
  )
  debug_inspect(p.constant, content="0")
  debug_inspect(
    p.distance_to_point(@math3d.Vector3::new(0.0, 0.0, 5.0)),
    content="5",
  )
  debug_inspect(
    p.distance_to_point(@math3d.Vector3::new(0.0, 0.0, -2.0)),
    content="-2",
  )
  // 三点定平面:a=(0,0,0) b=(1,0,0) c=(0,1,0) → z=0,法线 +Z
  let q = @math3d.Plane::set_from_coplanar_points(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
    @math3d.Vector3::unit_y(),
  )
  debug_inspect(q.normal.x.abs() < 0.0000001, content="true")
  debug_inspect((q.normal.z - 1.0).abs() < 0.0000001, content="true")
  debug_inspect(q.constant, content="0")
  // 过 (1,1,1) 的 z=1 平面:constant = -1
  let r = @math3d.Plane::set_from_normal_and_coplanar_point(
    @math3d.Vector3::unit_z(),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  debug_inspect(r.constant, content="-1")
}

///|
test "Plane normalize/negate" {
  // n=(0,0,2), c=4 与 n=(0,0,1), c=2 同一平面
  let p = @math3d.Plane::set_components(0.0, 0.0, 2.0, 4.0)
  let n = p.normalize()
  debug_inspect((n.normal.z - 1.0).abs() < 0.0000001, content="true")
  debug_inspect(n.constant, content="2")
  let g = p.negate()
  debug_inspect(g.normal.z, content="-2")
  debug_inspect(g.constant, content="-4")
  // 取反不改平面本身:距离变号
  debug_inspect(
    g.distance_to_point(@math3d.Vector3::new(0.0, 0.0, 5.0)) == -p.distance_to_point(
      @math3d.Vector3::new(0.0, 0.0, 5.0),
    ),
    content="true",
  )
}

///|
test "Plane project_point/coplanar_point/translate/distance_to_sphere" {
  let p = @math3d.Plane::set_components(0.0, 0.0, 1.0, 0.0) // z=0
  let proj = p.project_point(@math3d.Vector3::new(3.0, 4.0, 10.0))
  debug_inspect(proj.x, content="3")
  debug_inspect(proj.y, content="4")
  debug_inspect(proj.z, content="0")
  // coplanar_point = n * -c
  let q = @math3d.Plane::set_components(0.0, 0.0, 1.0, -5.0) // z=5
  let cp = q.coplanar_point()
  debug_inspect(cp.x, content="0")
  debug_inspect(cp.z, content="5")
  // 平移:沿 -Z 移 3 → z=-3 平面(constant=3)
  let t = p.translate(@math3d.Vector3::new(0.0, 0.0, -3.0))
  debug_inspect(t.constant, content="3")
  // 球到平面距离 = 球心距离 - 半径
  let s = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  debug_inspect(
    q.distance_to_sphere(s),
    content="-6",
  )
}

///|
test "Plane intersect_line/intersects_line" {
  let p = @math3d.Plane::set_components(0.0, 0.0, 1.0, 0.0) // z=0
  // 线段 (0,0,5)→(0,0,-5) 穿越 z=0 于原点
  let hit = p.intersect_line(
    @math3d.Vector3::new(0.0, 0.0, 5.0),
    @math3d.Vector3::new(0.0, 0.0, -5.0),
    true,
  )
  debug_inspect(hit.unwrap().z == 0.0 && hit.unwrap().x == 0.0, content="true")
  // 交点越界且 clamp → None;不 clamp → 延长线交点
  let start = @math3d.Vector3::new(0.0, 0.0, 5.0)
  let end = @math3d.Vector3::new(0.0, 0.0, 2.0)
  debug_inspect(p.intersect_line(start, end, true) is None, content="true")
  let loose = p.intersect_line(start, end, false).unwrap()
  debug_inspect(
    loose.x == 0.0 &&
    loose.y == 0.0 &&
    loose.z.abs() < 0.0000001,
    content="true",
  )
  // 平行且共面:返回起点
  let on = p.intersect_line(
    @math3d.Vector3::new(1.0, 0.0, 0.0),
    @math3d.Vector3::new(2.0, 0.0, 0.0),
    true,
  )
  debug_inspect(on.unwrap().x, content="1")
  // 平行不共面:None
  let off = @math3d.Plane::set_components(0.0, 0.0, 1.0, -5.0)
  debug_inspect(
    off.intersect_line(
      @math3d.Vector3::new(1.0, 0.0, 0.0),
      @math3d.Vector3::new(2.0, 0.0, 0.0),
      true,
    ) is None,
    content="true",
  )
  // 穿越判定:两端严格分居两侧
  debug_inspect(
    p.intersects_line(
      @math3d.Vector3::new(0.0, 0.0, 1.0),
      @math3d.Vector3::new(0.0, 0.0, -1.0),
    ),
    content="true",
  )
  debug_inspect(
    p.intersects_line(
      @math3d.Vector3::new(0.0, 0.0, 1.0),
      @math3d.Vector3::new(0.0, 0.0, 2.0),
    ),
    content="false",
  )
}

///|
test "Plane apply_matrix4:平移后平面随动" {
  // z=0 平面沿 +Z 平移 5 → z=5
  let p = @math3d.Plane::set_components(0.0, 0.0, 1.0, 0.0)
  let t = @math3d.Matrix4::make_translation(0.0, 0.0, 5.0)
  let moved = p.apply_matrix4(t)
  debug_inspect((moved.normal.z - 1.0).abs() < 0.0000001, content="true")
  debug_inspect(
    (moved.distance_to_point(@math3d.Vector3::new(0.0, 0.0, 5.0))).abs() <
    0.0000001,
    content="true",
  )
  debug_inspect(
    (moved.constant + 5.0).abs() < 0.0000001,
    content="true",
  )
  // 旋转(绕 X 90°):法线 (0,0,1) → (0,-1,0)(Z→-Y),平面变为 y=0
  let rot = p.apply_matrix4(
    @math3d.Matrix4::make_rotation_axis(
      @math3d.Vector3::unit_x(),
      1.5707963267948966,
    ),
  )
  debug_inspect(
    rot.normal.z.abs() < 0.0000001 &&
    rot.normal.x.abs() < 0.0000001 &&
    (rot.normal.y + 1.0).abs() < 0.0000001,
    content="true",
  )
}

///|
test "Plane 相交委托与 equals" {
  let p = @math3d.Plane::set_components(0.0, 0.0, 1.0, -1.0) // z=1
  let box = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  debug_inspect(p.intersects_box(box), content="true")
  debug_inspect(
    p.intersects_box(
      @math3d.Box3::new(
        @math3d.Vector3::new(-1.0, -1.0, -5.0),
        @math3d.Vector3::new(1.0, 1.0, -2.0),
      ),
    ),
    content="false",
  )
  // 球与平面:球心 z=0 r=1 恰触 z=1 平面
  debug_inspect(
    p.intersects_sphere(@math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)),
    content="true",
  )
  debug_inspect(
    p.intersects_sphere(@math3d.Sphere::new(@math3d.Vector3::zero(), 0.5)),
    content="false",
  )
  debug_inspect(p.equals(@math3d.Plane::set_components(0.0, 0.0, 1.0, -1.0)), content=(
    #|true
  ))
  debug_inspect(p.equals(@math3d.Plane::set_components(0.0, 0.0, 1.0, 0.0)), content=(
    #|false
  ))
}
