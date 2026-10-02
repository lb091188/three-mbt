///|
test "Ray at/look_at/recast" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  )
  let p = r.at(2.5)
  debug_inspect(p.x, content="2.5")
  debug_inspect(p.y, content="0")
  // 默认射线朝 -Z
  let d = @math3d.Ray::default()
  debug_inspect(d.direction.z, content="-1")
  let l = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  ).look_at(@math3d.Vector3::new(0.0, 5.0, 0.0))
  debug_inspect(l.direction.y, content="1")
  debug_inspect(l.direction.x, content="0")
  let rc = r.recast(3.0)
  debug_inspect(rc.origin.x, content="3")
  debug_inspect(rc.direction.x, content="1")
}

///|
test "Ray closest_point_to_point/distance" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  )
  let cp = r.closest_point_to_point(@math3d.Vector3::new(3.0, 5.0, 0.0))
  debug_inspect(cp.x, content="3")
  debug_inspect(cp.y, content="0")
  debug_inspect(
    r.distance_sq_to_point(@math3d.Vector3::new(3.0, 5.0, 0.0)),
    content="25",
  )
  debug_inspect(
    r.distance_to_point(@math3d.Vector3::new(3.0, 5.0, 0.0)),
    content="5",
  )
  // 点在射线后方:最近点退化为原点
  let behind = r.closest_point_to_point(@math3d.Vector3::new(-3.0, 5.0, 0.0))
  debug_inspect(
    behind.x == 0.0 && behind.y == 0.0 && behind.z == 0.0,
    content="true",
  )
  debug_inspect(
    r.distance_sq_to_point(@math3d.Vector3::new(-3.0, 5.0, 0.0)),
    content="34",
  )
}

///|
test "Ray distance_sq_to_segment(region0 垂直相交与 region4 端点)" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  )
  // 线段横跨射线:最近点重合,距离平方 0
  debug_inspect(
    r.distance_sq_to_segment(
      @math3d.Vector3::new(0.5, -1.0, 0.0),
      @math3d.Vector3::new(0.5, 1.0, 0.0),
    ),
    content="0",
  )
  // 线段在原点后方:最近对 = (原点, 线段近端 (-2,1,0)),距离平方 5
  let (d, on_ray, on_seg) = r.distance_sq_to_segment_with_points(
    @math3d.Vector3::new(-2.0, 1.0, 0.0),
    @math3d.Vector3::new(-2.0, 3.0, 0.0),
  )
  debug_inspect(d, content="5")
  debug_inspect(
    on_ray.x == 0.0 && on_ray.y == 0.0,
    content="true",
  )
  debug_inspect(
    on_seg.x == -2.0 && on_seg.y == 1.0 && on_seg.z == 0.0,
    content="true",
  )
  // 与射线平行的线段
  debug_inspect(
    r.distance_sq_to_segment(
      @math3d.Vector3::new(1.0, 2.0, 0.0),
      @math3d.Vector3::new(5.0, 2.0, 0.0),
    ),
    content="4",
  )
}

///|
test "Ray intersect_sphere(命中/内部/未中/空球)" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
  )
  let hit = r.intersect_sphere(
    @math3d.Sphere::new(@math3d.Vector3::new(0.0, 0.0, -5.0), 1.0),
  )
  debug_inspect(
    hit.unwrap().z,
    content="-4",
  )
  // 起点在球内:返回出口点
  let inside = r.intersect_sphere(
    @math3d.Sphere::new(@math3d.Vector3::zero(), 1.0),
  )
  debug_inspect(inside.unwrap().z, content="-1")
  // 擦肩而过
  debug_inspect(
    r.intersect_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(0.0, 5.0, -5.0), 1.0),
    ) is None,
    content="true",
  )
  // 球整体在射线后方
  debug_inspect(
    r.intersect_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(0.0, 0.0, 5.0), 1.0),
    ) is None,
    content="true",
  )
  // 空球(three.js #31187):None / false
  debug_inspect(
    r.intersect_sphere(@math3d.Sphere::empty()) is None,
    content="true",
  )
  debug_inspect(
    r.intersects_sphere(@math3d.Sphere::empty()),
    content="false",
  )
  debug_inspect(
    r.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(0.0, 0.0, -5.0), 1.0),
    ),
    content="true",
  )
}

///|
test "Ray 与平面(交点/背面/平行)" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
  )
  // z=-5 平面:n=(0,0,1) c=5
  let plane = @math3d.Plane::set_components(0.0, 0.0, 1.0, 5.0)
  debug_inspect(r.distance_to_plane(plane).unwrap(), content="5")
  let hit = r.intersect_plane(plane)
  debug_inspect(hit.unwrap().z, content="-5")
  // 朝向背离平面:无交
  let back = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::new(0.0, 0.0, 1.0),
  )
  debug_inspect(back.distance_to_plane(plane) is None, content="true")
  debug_inspect(back.intersects_plane(plane), content="false")
  debug_inspect(r.intersects_plane(plane), content="true")
  // 平行且不在平面上(x=-1 平面,原点距离 1)
  let parallel_plane = @math3d.Plane::set_components(1.0, 0.0, 0.0, 1.0)
  debug_inspect(
    r.distance_to_plane(parallel_plane) is None,
    content="true",
  )
  // 原点在平面上:t=0
  let through = @math3d.Ray::new(
    @math3d.Vector3::new(0.0, 0.0, -5.0),
    @math3d.Vector3::new(0.0, 1.0, 0.0),
  )
  debug_inspect(through.distance_to_plane(plane).unwrap(), content="0")
  debug_inspect(through.intersects_plane(plane), content="true")
}

///|
test "Ray intersect_box(slab 法,含背向剔除)" {
  let box = @math3d.Box3::new(
    @math3d.Vector3::new(-1.0, -1.0, -1.0),
    @math3d.Vector3::new(1.0, 1.0, 1.0),
  )
  let r = @math3d.Ray::new(
    @math3d.Vector3::new(0.0, 0.0, 5.0),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
  )
  let hit = r.intersect_box(box)
  debug_inspect(hit.unwrap().z, content="1")
  debug_inspect(r.intersects_box(box), content="true")
  // 盒在射线后方
  let away = @math3d.Ray::new(
    @math3d.Vector3::new(0.0, 0.0, 5.0),
    @math3d.Vector3::new(0.0, 0.0, 1.0),
  )
  debug_inspect(away.intersect_box(box) is None, content="true")
  // 侧向未中
  let side = @math3d.Ray::new(
    @math3d.Vector3::new(5.0, 0.0, 5.0),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
  )
  debug_inspect(side.intersect_box(box) is None, content="true")
  // 起点在盒内:返回出口点(tmin<0 取 tmax)
  let inner = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  )
  debug_inspect(inner.intersect_box(box).unwrap().x, content="1")
}

///|
test "Ray intersect_triangle(watertight,含背面剔除)" {
  let ray = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
  )
  // 逆时针(自 +Z 视角):法线朝 +Z,面向射线
  let a = @math3d.Vector3::new(-1.0, -1.0, -1.0)
  let b = @math3d.Vector3::new(1.0, -1.0, -1.0)
  let c = @math3d.Vector3::new(0.0, 1.0, -1.0)
  let hit = ray.intersect_triangle(a, b, c, false)
  debug_inspect(
    hit.unwrap().x.abs() < 0.0000001 &&
    hit.unwrap().y.abs() < 0.0000001 &&
    hit.unwrap().z == -1.0,
    content="true",
  )
  // 正面命中不受背面剔除影响
  debug_inspect(
    ray.intersect_triangle(a, b, c, true).unwrap().z,
    content="-1",
  )
  // 反绕(法线 -Z):背面;剔除时 None,不剔时仍命中
  debug_inspect(
    ray.intersect_triangle(a, c, b, true) is None,
    content="true",
  )
  debug_inspect(
    ray.intersect_triangle(a, c, b, false).unwrap().z,
    content="-1",
  )
  // 三角形在射线后方:None
  let front_tri = @math3d.Vector3::new(-1.0, -1.0, 5.0)
  debug_inspect(
    ray.intersect_triangle(
      front_tri,
      @math3d.Vector3::new(1.0, -1.0, 5.0),
      @math3d.Vector3::new(0.0, 1.0, 5.0),
      false,
    ) is None,
    content="true",
  )
  // 未命中(打在三角形外)
  debug_inspect(
    ray.intersect_triangle(
      @math3d.Vector3::new(2.0, 2.0, -1.0),
      @math3d.Vector3::new(4.0, 2.0, -1.0),
      @math3d.Vector3::new(3.0, 4.0, -1.0),
      false,
    ) is None,
    content="true",
  )
}

///|
test "Ray apply_matrix4/equals" {
  let r = @math3d.Ray::new(
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
  )
  let moved = r.apply_matrix4(@math3d.Matrix4::make_translation(5.0, 0.0, 0.0))
  debug_inspect(moved.origin.x, content="5")
  debug_inspect(moved.direction.x, content="1")
  // 方向经变换后归一(three.js transformDirection)
  let scaled = r.apply_matrix4(@math3d.Matrix4::make_scale(2.0, 2.0, 2.0))
  debug_inspect(scaled.direction.x, content="1")
  debug_inspect(scaled.origin.x, content="0")
  debug_inspect(
    moved.equals(@math3d.Ray::new(
      @math3d.Vector3::new(5.0, 0.0, 0.0),
      @math3d.Vector3::unit_x(),
    )),
    content="true",
  )
  debug_inspect(moved.equals(r), content="false")
}
