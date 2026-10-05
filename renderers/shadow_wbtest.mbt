// A5 阴影纯函数测试:深度 pass 收集与阴影视锥矩阵(GPU 无关部分)。

///| 深度 pass 收集:只收 visible 且 cast_shadow 的 mesh 节点,

///|
/// 含嵌套子节点;隐藏/关投影视/纯组节点皆不收
test "collect_shadow_casters:可见+cast_shadow 过滤与嵌套收集" {
  let scene = @core.Scene::new()
  // 投影箱(默认 cast_shadow=true)
  let caster = @core.Mesh::new(
    @core.BufferGeometry::box(2.0, 2.0, 2.0),
    @core.Material::lambert(@math3d.Color::red(), @math3d.Color::black()),
  )
  caster.position = @math3d.Vector3::new(3.0, 1.0, 0.0)
  scene.add(caster)
  // 关投影的箱
  let no_cast = @core.Mesh::new(
    @core.BufferGeometry::box(2.0, 2.0, 2.0),
    @core.Material::lambert(@math3d.Color::blue(), @math3d.Color::black()),
  )
  no_cast.mesh.unwrap().cast_shadow = false
  scene.add(no_cast)
  // 隐藏的箱
  let hidden = @core.Mesh::new(
    @core.BufferGeometry::box(2.0, 2.0, 2.0),
    @core.Material::lambert(@math3d.Color::green(), @math3d.Color::black()),
  )
  hidden.visible = false
  scene.add(hidden)
  // 嵌套子节点(挂在投影组下)
  let group = @core.Object3D::new()
  let nested = @core.Mesh::new(
    @core.BufferGeometry::box(1.0, 1.0, 1.0),
    @core.Material::lambert(@math3d.Color::white(), @math3d.Color::black()),
  )
  group.add(nested)
  scene.add(group)
  // receive_shadow 不影响收集(那是主 pass 语义)
  let recv_only = @core.Mesh::new(
    @core.BufferGeometry::box(4.0, 0.1, 4.0),
    @core.Material::lambert(@math3d.Color::white(), @math3d.Color::black()),
  )
  recv_only.mesh.unwrap().cast_shadow = false
  recv_only.mesh.unwrap().receive_shadow = true
  scene.add(recv_only)
  let casters = collect_shadow_casters(scene)
  debug_inspect(casters.length() == 2, content="true")
  debug_inspect(casters[0].id == caster.id, content="true")
  debug_inspect(casters[1].id == nested.id, content="true")
}

///| 阴影视图矩阵:光源 (0,8,6) 看向原点(direction=指向光源的单位向量),

///|
/// 原点应落在视空间 z=-10(视距 10,相机看 -z)
test "shadow_view_matrix:光源位置看向 direction 反向,目标在 -z" {
  let eye = @math3d.Vector3::new(0.0, 8.0, 6.0)
  let light : @core.SceneDirectionalLight = {
    direction: eye.normalize(),
    color: @math3d.Color::white(),
    intensity: 1.0,
    position: eye,
    cast_shadow: true,
    shadow: @core.DirectionalLightShadow::new(),
  }
  let v = shadow_view_matrix(light)
  let o = v.apply_point(@math3d.Vector3::zero())
  debug_inspect(o.x.abs() < 0.0000001, content="true")
  debug_inspect(o.y.abs() < 0.0000001, content="true")
  debug_inspect((o.z + 10.0).abs() < 0.000001, content="true")
  // 光源自身位置映射到视空间原点
  let e = v.apply_point(eye)
  debug_inspect(e.length2() < 0.0000001, content="true")
}

///| 阴影正交投影:视锥 ±5 时 x=+2.5 → NDC +0.5;near/far 与 WebGPU

///|
/// z∈[0,1] 裁剪域一致(近面 0、远面 1)
test "shadow_projection_matrix:正交视锥线性映射与 z 出自 make_orthographic" {
  let light : @core.SceneDirectionalLight = {
    direction: @math3d.Vector3::unit_y(),
    color: @math3d.Color::white(),
    intensity: 1.0,
    position: @math3d.Vector3::new(0.0, 10.0, 0.0),
    cast_shadow: true,
    shadow: @core.DirectionalLightShadow::new(),
  }
  light.shadow.camera.left = -5.0
  light.shadow.camera.right = 5.0
  light.shadow.camera.top = 5.0
  light.shadow.camera.bottom = -5.0
  light.shadow.camera.near = 1.0
  light.shadow.camera.far = 101.0
  let p = shadow_projection_matrix(light)
  let a = p.apply_point(@math3d.Vector3::new(2.5, 0.0, 0.0))
  debug_inspect((a.x - 0.5).abs() < 0.0000001, content="true")
  debug_inspect(a.y.abs() < 0.0000001, content="true")
  // 与 math3d make_orthographic(WebGPU 分支)逐元素一致
  let want = @math3d.Matrix4::make_orthographic(
    -5.0, 5.0, 5.0, -5.0, 1.0, 101.0,
  )
  for i, e in want.e {
    debug_inspect((p.e[i] - e).abs() < 0.0000001, content="true")
  }
}

///| 阴影矩阵全链:倾齐光源下,正下方原点应映射到贴图中心 (0.5,0.5)、

///|
/// 深度在 [0,1];x 方向偏移按视锥宽度线性进入 u
test "shadow_light_matrix:proj×view 组合,原点在贴图中心、z 归一" {
  let eye = @math3d.Vector3::new(0.0, 8.0, 6.0)
  let light : @core.SceneDirectionalLight = {
    direction: eye.normalize(),
    color: @math3d.Color::white(),
    intensity: 1.0,
    position: eye,
    cast_shadow: true,
    shadow: @core.DirectionalLightShadow::new(),
  }
  light.shadow.camera.left = -10.0
  light.shadow.camera.right = 10.0
  light.shadow.camera.top = 10.0
  light.shadow.camera.bottom = -10.0
  light.shadow.camera.near = 1.0
  light.shadow.camera.far = 100.0
  let m = shadow_light_matrix(light)
  // 世界原点(光源正下方 10 单位)→ 裁剪 (0,0,z),z=(视距-near)/(far-near)
  let c = m.apply_point(@math3d.Vector3::zero())
  debug_inspect(c.x.abs() < 0.0000001, content="true")
  debug_inspect(c.y.abs() < 0.0000001, content="true")
  debug_inspect((c.z - 9.0 / 99.0).abs() < 0.000001, content="true")
  debug_inspect(c.z > 0.0 && c.z < 1.0, content="true")
  // 沿世界 +x 摆 5 单位的点:阴影视锥 ±10 半宽,光轴右向(make_look_at
  // 归一化后)= 世界 +x,视空间 x = 5 → NDC x = 0.5(UV 0.5 偏置在 shader 内)
  let side = m.apply_point(@math3d.Vector3::new(5.0, 0.0, 0.0))
  debug_inspect((side.x - 0.5).abs() < 0.000001, content="true")
}

///|
/// Mesh 阴影开关默认全开(任务要求);glTF 加载路径同默认
test "Mesh::new 默认 cast/receive true" {
  let m = @core.Mesh::new(
    @core.BufferGeometry::box(1.0, 1.0, 1.0),
    @core.Material::lambert(@math3d.Color::white(), @math3d.Color::black()),
  ).mesh.unwrap()
  debug_inspect(m.cast_shadow, content="true")
  debug_inspect(m.receive_shadow, content="true")
  // 可单独关:receive 关后主 pass uniform 阴影段不启用(wbtest 锁偏移)
  m.receive_shadow = false
  debug_inspect(!m.receive_shadow, content="true")
}
