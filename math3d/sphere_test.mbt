///|
test "Sphere 空球与 set_from_points" {
  let e = @math3d.Sphere::empty()
  debug_inspect(e.is_empty(), content="true")
  debug_inspect(e.radius, content="-1")
  // 半径 0 只含中心点,不算空
  let point = @math3d.Sphere::new(@math3d.Vector3::zero(), 0.0)
  debug_inspect(point.is_empty(), content="false")
  debug_inspect(point.contains_point(@math3d.Vector3::zero()), content="true")
  let s = @math3d.Sphere::set_from_points([
    @math3d.Vector3::new(1.0, 0.0, 0.0),
    @math3d.Vector3::new(-1.0, 0.0, 0.0),
    @math3d.Vector3::new(0.0, 1.0, 0.0),
  ])
  // 球心 = 包围盒中心 (0, 0.5, 0);半径 = sqrt(1.25)
  debug_inspect(s.center.x, content="0")
  debug_inspect(s.center.y, content="0.5")
  debug_inspect(s.radius, content="1.118033988749895")
  // 指定球心分支:球心原点半径 1
  let c = @math3d.Sphere::set_from_points_centered(
    [
      @math3d.Vector3::new(1.0, 0.0, 0.0),
      @math3d.Vector3::new(-1.0, 0.0, 0.0),
    ],
    @math3d.Vector3::zero(),
  )
  debug_inspect(c.radius, content="1")
}

///|
test "Sphere contains/distance/intersects" {
  let s = @math3d.Sphere::new(@math3d.Vector3::zero(), 2.0)
  debug_inspect(
    s.contains_point(@math3d.Vector3::new(0.0, 0.0, 2.0)),
    content="true",
  )
  debug_inspect(
    s.contains_point(@math3d.Vector3::new(0.0, 0.0, 2.1)),
    content="false",
  )
  // 内部点距离为负
  debug_inspect(
    s.distance_to_point(@math3d.Vector3::zero()),
    content="-2",
  )
  debug_inspect(
    s.distance_to_point(@math3d.Vector3::new(0.0, 0.0, 5.0)),
    content="3",
  )
  debug_inspect(
    s.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 1.0),
    ),
    content="true",
  )
  debug_inspect(
    s.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(3.5, 0.0, 0.0), 1.0),
    ),
    content="false",
  )
  // 与平面:球心 (0,0,0) r=1 对 z=1 平面恰好接触
  let plane = @math3d.Plane::set_components(0.0, 0.0, 1.0, -1.0)
  debug_inspect(
    @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0).intersects_plane(plane),
    content="true",
  )
  debug_inspect(
    @math3d.Sphere::new(@math3d.Vector3::zero(), 0.5).intersects_plane(plane),
    content="false",
  )
  // 与盒:委托 Box3::intersects_sphere
  let box = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  debug_inspect(
    @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 2.5).intersects_box(
      box,
    ),
    content="true",
  )
  debug_inspect(
    @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 1.5).intersects_box(
      box,
    ),
    content="false",
  )
}

///|
test "Sphere clamp_point/get_bounding_box" {
  let s = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  let out = s.clamp_point(@math3d.Vector3::new(3.0, 4.0, 0.0))
  debug_inspect((out.x - 0.6).abs() < 0.0000001, content="true")
  debug_inspect((out.y - 0.8).abs() < 0.0000001, content="true")
  debug_inspect(out.z, content="0")
  // 内部点原样返回
  let inside = @math3d.Vector3::new(0.1, 0.0, 0.0)
  let kept = s.clamp_point(inside)
  debug_inspect(
    kept.x == 0.1 && kept.y == 0.0 && kept.z == 0.0,
    content="true",
  )
  let b = @math3d.Sphere::new(@math3d.Vector3::new(1.0, 2.0, 3.0), 2.0).get_bounding_box()
  debug_inspect(b.min.x, content="-1")
  debug_inspect(b.max.x, content="3")
  debug_inspect(b.min.y, content="0")
  debug_inspect(b.max.z, content="5")
  // 空球 → 空盒
  debug_inspect(
    @math3d.Sphere::empty().get_bounding_box().is_empty(),
    content="true",
  )
}

///|
test "Sphere apply_matrix4/translate" {
  let s = @math3d.Sphere::new(@math3d.Vector3::new(1.0, 0.0, 0.0), 2.0)
  let scaled = s.apply_matrix4(@math3d.Matrix4::make_scale(2.0, 2.0, 2.0))
  debug_inspect(scaled.center.x, content="2")
  debug_inspect(scaled.radius, content="4")
  let moved = s.translate(@math3d.Vector3::new(1.0, 1.0, 0.0))
  debug_inspect(moved.center.x, content="2")
  debug_inspect(moved.center.y, content="1")
  debug_inspect(moved.radius, content="2")
}

///|
test "Sphere expand_by_point(three.js 最小球扩张)" {
  // 空球收入首点:球心=点,半径 0
  let first = @math3d.Sphere::empty().expand_by_point(
    @math3d.Vector3::new(1.0, 2.0, 3.0),
  )
  debug_inspect(first.radius, content="0")
  debug_inspect(first.center.x, content="1")
  // 半径 1 的球收入 (4,0,0):新球心 (1.5,0,0) 半径 2.5
  let s = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  let grown = s.expand_by_point(@math3d.Vector3::new(4.0, 0.0, 0.0))
  debug_inspect(grown.center.x, content="1.5")
  debug_inspect(grown.radius, content="2.5")
  // 球内点不改变球
  let kept = s.expand_by_point(@math3d.Vector3::new(0.5, 0.0, 0.0))
  debug_inspect(kept.center.x == 0.0 && kept.radius == 1.0, content="true")
}

///|
test "Sphere union(同心取大 / 异心两端扩张)" {
  // 同心:r = max(1, 3) = 3
  let a = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  let b = @math3d.Sphere::new(@math3d.Vector3::zero(), 3.0)
  let same = a.union(b)
  debug_inspect(same.center.x == 0.0, content="true")
  debug_inspect(same.radius, content="3")
  // 异心:A 球心 0 r=1、B 球心 (3,0,0) r=1:先收远端 (4,0,0) 得
  // 球心 (1.5,0,0) 半径 2.5,近端 (2,0,0) 已在内
  let c = @math3d.Sphere::new(@math3d.Vector3::new(3.0, 0.0, 0.0), 1.0)
  let u = a.union(c)
  debug_inspect(u.center.x, content="1.5")
  debug_inspect(u.radius, content="2.5")
  // 与空球 union:另一侧原样
  debug_inspect(a.union(@math3d.Sphere::empty()).radius, content="1")
  debug_inspect(
    @math3d.Sphere::empty().union(a).radius,
    content="1",
  )
  debug_inspect(
    @math3d.Sphere::empty().union(a).center.x,
    content="0",
  )
}

///|
test "Sphere equals" {
  let a = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  let b = @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0)
  let c = @math3d.Sphere::new(@math3d.Vector3::zero(), 2.0)
  debug_inspect(a.equals(b), content="true")
  debug_inspect(a.equals(c), content="false")
}
