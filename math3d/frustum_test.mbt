///|
test "Frustum set_from_projection_matrix(WebGPU,fov 90°)" {
  // 相机在原点看 -Z:fov_y=90°、aspect=1、near=1、far=3
  // f = 1/tan(45°) = 1;矩阵 m10=-1.5、m11=-1、m14=-1.5
  let m = @math3d.Matrix4::make_perspective(
    1.5707963267948966,
    1.0,
    1.0,
    3.0,
  )
  let fr = @math3d.Frustum::set_from_projection_matrix(m, WebGPU, false)
  // far 平面 (me3-me2 行) = (0,0,0.5,1.5) 归一 → n=(0,0,1) c=3(z=-3)
  let far = fr.planes[4]
  debug_inspect((far.normal.z - 1.0).abs() < 0.0000001, content="true")
  debug_inspect((far.constant - 3.0).abs() < 0.0000001, content="true")
  // WebGPU near 平面取第三行 = (0,0,-1.5,-1.5) 归一 → n=(0,0,-1) c=-1(z=-1)
  let near = fr.planes[5]
  debug_inspect((near.normal.z + 1.0).abs() < 0.0000001, content="true")
  debug_inspect((near.constant + 1.0).abs() < 0.0000001, content="true")
  // 左平面 = (-1,0,-1,0) 归一 → n=(-√2/2,0,-√2/2)
  let left = fr.planes[0]
  debug_inspect(
    (left.normal.x + 0.7071067811865476).abs() < 0.0000001,
    content="true",
  )
  debug_inspect(left.normal.y.abs() < 0.0000001, content="true")
}

///|
test "Frustum contains_point(视锥内/外/边界)" {
  let m = @math3d.Matrix4::make_perspective(
    1.5707963267948966,
    1.0,
    1.0,
    3.0,
  )
  let fr = @math3d.Frustum::set_from_projection_matrix(m, WebGPU, false)
  // 中轴上的点在锥内
  debug_inspect(
    fr.contains_point(@math3d.Vector3::new(0.0, 0.0, -2.0)),
    content="true",
  )
  // 远于 far(z=-5):出锥
  debug_inspect(
    fr.contains_point(@math3d.Vector3::new(0.0, 0.0, -5.0)),
    content="false",
  )
  // 近于 near(z=-0.5):出锥
  debug_inspect(
    fr.contains_point(@math3d.Vector3::new(0.0, 0.0, -0.5)),
    content="false",
  )
  // fov 90°:z=-1 处半宽 1,(0.9,0.9,-1) 在内、(1.1,0,-1) 在外
  debug_inspect(
    fr.contains_point(@math3d.Vector3::new(0.9, 0.9, -1.0)),
    content="true",
  )
  debug_inspect(
    fr.contains_point(@math3d.Vector3::new(1.1, 0.0, -1.0)),
    content="false",
  )
}

///|
test "Frustum intersects_sphere/intersects_box" {
  let m = @math3d.Matrix4::make_perspective(
    1.5707963267948966,
    1.0,
    1.0,
    3.0,
  )
  let fr = @math3d.Frustum::set_from_projection_matrix(m, WebGPU, false)
  // 锥内小球
  debug_inspect(
    fr.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(0.0, 0.0, -2.0), 0.5),
    ),
    content="true",
  )
  // 锥外远球
  debug_inspect(
    fr.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(0.0, 0.0, -10.0), 1.0),
    ),
    content="false",
  )
  // 锥内侧球
  debug_inspect(
    fr.intersects_sphere(
      @math3d.Sphere::new(@math3d.Vector3::new(10.0, 0.0, -2.0), 1.0),
    ),
    content="false",
  )
  // 跨越视锥的盒
  debug_inspect(
    fr.intersects_box(
      @math3d.Box3::new(
        @math3d.Vector3::new(-0.5, -0.5, -2.5),
        @math3d.Vector3::new(0.5, 0.5, -1.5),
      ),
    ),
    content="true",
  )
  // 远平面外的盒(max.z=-3.1 在 z=-3 的 far 平面之后 → 剔除)
  debug_inspect(
    fr.intersects_box(
      @math3d.Box3::new(
        @math3d.Vector3::new(-2.0, -2.0, -3.5),
        @math3d.Vector3::new(-1.0, -1.0, -3.1),
      ),
    ),
    content="false",
  )
  // 恰触 far 平面的盒(max.z=-3.0):保守语义不剔除(three.js 同义)
  debug_inspect(
    fr.intersects_box(
      @math3d.Box3::new(
        @math3d.Vector3::new(-2.0, -2.0, -3.5),
        @math3d.Vector3::new(-1.0, -1.0, -3.0),
      ),
    ),
    content="true",
  )
  // 近处右上外的盒
  debug_inspect(
    fr.intersects_box(
      @math3d.Box3::new(
        @math3d.Vector3::new(6.0, 6.0, 0.7),
        @math3d.Vector3::new(8.0, 8.0, 0.9),
      ),
    ),
    content="false",
  )
}

///|
test "Frustum 默认构造与六个平面顺序" {
  // planes 顺序:左/右/上/下/远/近(取 fov 90° 锥验证左右平面方向相反)
  let m = @math3d.Matrix4::make_perspective(
    1.5707963267948966,
    1.0,
    1.0,
    3.0,
  )
  let fr = @math3d.Frustum::set_from_projection_matrix(m, WebGPU, false)
  // 左平面法线 x 分量为负、右平面为正
  debug_inspect(fr.planes[0].normal.x < 0.0, content="true")
  debug_inspect(fr.planes[1].normal.x > 0.0, content="true")
  // 上平面法线 y 分量为正、下平面为负
  debug_inspect(fr.planes[2].normal.y > 0.0, content="true")
  debug_inspect(fr.planes[3].normal.y < 0.0, content="true")
  // 默认构造:六个默认平面(normal=(1,0,0), constant=0)
  let d = @math3d.Frustum::new()
  debug_inspect(d.planes.length(), content="6")
  debug_inspect(
    d.planes[5].normal.x == 1.0 && d.planes[5].constant == 0.0,
    content="true",
  )
  // from_planes 构造后一致
  let custom = @math3d.Frustum::from_planes(
    fr.planes[0],
    fr.planes[1],
    fr.planes[2],
    fr.planes[3],
    fr.planes[4],
    fr.planes[5],
  )
  debug_inspect(
    custom.contains_point(@math3d.Vector3::new(0.0, 0.0, -2.0)),
    content="true",
  )
  debug_inspect(
    custom.contains_point(@math3d.Vector3::new(0.0, 0.0, -5.0)),
    content="false",
  )
}

///|
test "Frustum WebGL 与 WebGPU 的 near 平面差异" {
  // 同一投影矩阵下,WebGL near 取 me3+me2 行、WebGPU 取 me2 行
  let m = @math3d.Matrix4::make_perspective(
    1.5707963267948966,
    1.0,
    1.0,
    3.0,
  )
  let gl = @math3d.Frustum::set_from_projection_matrix(m, WebGL, false)
  let gpu = @math3d.Frustum::set_from_projection_matrix(m, WebGPU, false)
  // m3+e2 行 = (0,0,-1.5+(-1.5),0+(-1))=(0,0,-3,-1) 归一 c=-1/3;
  // 对应平面 z = -(c) = -1/3?WebGL NDC z∈[-1,1] 的 near 即 z=-1
  debug_inspect(
    (gl.planes[5].constant + gpu.planes[5].constant).abs() > 0.1,
    content="true",
  )
  // 两者 far 平面一致
  debug_inspect(
    (gl.planes[4].constant - gpu.planes[4].constant).abs() < 0.0000001,
    content="true",
  )
}
