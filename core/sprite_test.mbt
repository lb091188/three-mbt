// core 包黑盒测试:A8 公告板精灵(朝向计算/锚点/世界四角)。

///|
test "billboard_axes:恒等相机 → 右=(1,0,0) 上=(0,1,0)" {
  let (right, up) = @core.billboard_axes(@math3d.Matrix4::identity())
  debug_inspect(
    right.equals(@math3d.Vector3::new(1.0, 0.0, 0.0)),
    content="true",
  )
  debug_inspect(up.equals(@math3d.Vector3::new(0.0, 1.0, 0.0)), content="true")
}

///|
test "billboard_axes:绕 Y 转 90° 的相机 → 右轴随动到 -Z,上轴不变" {
  // 相机世界旋转 = 绕 Y 轴 +90°(看向 -X):世界右轴 = 旋转作用于 (1,0,0)
  let cam_world = @math3d.Matrix4::make_rotation_axis(
    @math3d.Vector3::unit_y(),
    1.5707963267948966,
  )
  let (right, up) = @core.billboard_axes(cam_world)
  debug_inspect(
    (right.x - 0.0).abs() < 0.000001 &&
    (right.y - 0.0).abs() < 0.000001 &&
    (right.z + 1.0).abs() < 0.000001,
    content="true",
  )
  debug_inspect(
    (up.x - 0.0).abs() < 0.000001 &&
    (up.y - 1.0).abs() < 0.000001 &&
    (up.z - 0.0).abs() < 0.000001,
    content="true",
  )
}

///|
test "billboard_axes:带缩放的相机世界矩阵 → 轴仍为单位向量" {
  let scaled = @math3d.Matrix4::make_translation(5.0, 0.0, 0.0).multiply(
    @math3d.Matrix4::make_scale(3.0, 3.0, 3.0),
  )
  let (right, up) = @core.billboard_axes(scaled)
  debug_inspect((right.length() - 1.0).abs() < 0.000001, content="true")
  debug_inspect((up.length() - 1.0).abs() < 0.000001, content="true")
}

///|
test "billboard_axes_of:PerspectiveCamera look_at 后轴与视线正交朝相机" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  cam.look_at(@math3d.Vector3::new(0.0, 0.0, 5.0), @math3d.Vector3::zero())
  let (right, up) = @core.billboard_axes_of(cam)
  debug_inspect((right.length() - 1.0).abs() < 0.000001, content="true")
  debug_inspect((up.length() - 1.0).abs() < 0.000001, content="true")
  // 右/上轴互相垂直,且都垂直于视线方向(相机 -Z 指向 target → 世界
  // 视线 = -1 * 第 2 列);公告板平面法线 = right×up,应指向相机一侧
  let normal = right.cross(up)
  let to_cam = @math3d.Vector3::new(0.0, 0.0, 5.0)
  debug_inspect((right.dot(up) - 0.0).abs() < 0.000001, content="true")
  debug_inspect(normal.dot(to_cam) > 0.0, content="true")
}

///|
test "sprite_world_quad:锚点 0.5 四角 = center ± 半尺寸" {
  let (right, up) = (@math3d.Vector3::unit_x(), @math3d.Vector3::unit_y())
  let corners = @core.sprite_world_quad(
    @math3d.Vector3::new(1.0, 2.0, 3.0),
    2.0,
    4.0,
    right,
    up,
    @math3d.Vector2::new(0.5, 0.5),
  )
  // 顶点序:左下/右下/右上/左上
  debug_inspect(
    corners[0].equals(@math3d.Vector3::new(0.0, 0.0, 3.0)),
    content="true",
  )
  debug_inspect(
    corners[1].equals(@math3d.Vector3::new(2.0, 0.0, 3.0)),
    content="true",
  )
  debug_inspect(
    corners[2].equals(@math3d.Vector3::new(2.0, 4.0, 3.0)),
    content="true",
  )
  debug_inspect(
    corners[3].equals(@math3d.Vector3::new(0.0, 4.0, 3.0)),
    content="true",
  )
}

///|
test "sprite_world_quad:锚点 (0,0.5) → 四边形整体左移一个宽" {
  let corners = @core.sprite_world_quad(
    @math3d.Vector3::zero(),
    2.0,
    2.0,
    @math3d.Vector3::unit_x(),
    @math3d.Vector3::unit_y(),
    @math3d.Vector2::new(0.0, 0.5),
  )
  // dx = -0.5 → x ∈ [-2, 0]
  debug_inspect((corners[0].x + 2.0).abs() < 0.000001, content="true")
  debug_inspect((corners[1].x - 0.0).abs() < 0.000001, content="true")
}

///|
test "sprite_write_quad 与 sprite_world_quad 逐顶点一致" {
  let right = @math3d.Vector3::new(0.8, 0.0, -0.6)
  let up = @math3d.Vector3::unit_y()
  let center = @math3d.Vector3::new(1.0, 2.0, 3.0)
  let positions : Array[Double] = Array::make(12, 0.0)
  @core.sprite_write_quad(positions, 0, center, 2.0, 1.0, right, up)
  let corners = @core.sprite_world_quad(
    center,
    2.0,
    1.0,
    right,
    up,
    @math3d.Vector2::new(0.5, 0.5),
  )
  for j in 0..<4 {
    debug_inspect(
      (positions[j * 3] - corners[j].x).abs() < 0.000001 &&
      (positions[j * 3 + 1] - corners[j].y).abs() < 0.000001 &&
      (positions[j * 3 + 2] - corners[j].z).abs() < 0.000001,
      content="true",
    )
  }
}

///|
test "sprite_anchor_shift:0.5 锚点零平移,(0,0.5) 左移半宽" {
  let zero = @core.sprite_anchor_shift(
    @math3d.Vector2::new(0.5, 0.5),
    2.0,
    4.0,
    @math3d.Vector3::unit_x(),
    @math3d.Vector3::unit_y(),
  )
  debug_inspect(zero.equals(@math3d.Vector3::zero()), content="true")
  let shifted = @core.sprite_anchor_shift(
    @math3d.Vector2::new(0.0, 0.5),
    2.0,
    4.0,
    @math3d.Vector3::unit_x(),
    @math3d.Vector3::unit_y(),
  )
  debug_inspect((shifted.x + 1.0).abs() < 0.000001, content="true")
  debug_inspect((shifted.y - 0.0).abs() < 0.000001, content="true")
}

///|
test "BufferGeometry::sprite_quad:12 顶点分量/8 uv/6 索引,法线为空" {
  let g = @core.BufferGeometry::sprite_quad()
  debug_inspect(g.positions.length(), content="12")
  debug_inspect(g.uvs.length(), content="8")
  debug_inspect(g.indices.length(), content="6")
  debug_inspect(g.normals.length(), content="0")
  debug_inspect(g.vertex_count(), content="4")
  // 索引两三角共享对角线 0-2
  debug_inspect(
    g.indices[0] == 0U && g.indices[1] == 1U && g.indices[2] == 2U,
    content="true",
  )
  debug_inspect(
    g.indices[3] == 0U && g.indices[4] == 2U && g.indices[5] == 3U,
    content="true",
  )
}

///|
test "Material::sprite/particle:kind 标签与默认透明参数" {
  let sm = @core.Material::sprite(@math3d.Color::white())
  debug_inspect(sm.is_sprite(), content="true")
  debug_inspect(sm.is_billboard(), content="true")
  debug_inspect(sm.lit(), content="false")
  debug_inspect(sm.opacity == 1.0, content="true")
  debug_inspect(
    sm.center.equals(@math3d.Vector2::new(0.5, 0.5)),
    content="true",
  )
  debug_inspect(sm.rotation == 0.0, content="true")
  let pm = @core.Material::particle(@math3d.Color::white())
  debug_inspect(pm.is_particle(), content="true")
  debug_inspect(pm.is_sprite(), content="false")
  debug_inspect(pm.is_billboard(), content="true")
}
