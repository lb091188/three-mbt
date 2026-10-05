// core 包黑盒测试:A8 最简粒子系统(CPU 步进/动态几何/退化折叠)。

///|
test "粒子 integrate:重力加速度与位置积分" {
  let ps = @core.ParticleSystem::new(
    8,
    @core.Material::particle(@math3d.Color::white()),
  )
  ps.gravity = -10.0
  let _ = ps.spawn(0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 1.0, 0.5)
  debug_inspect(ps.alive_count(), content="1")
  ps.integrate(0.1)
  let p = ps.particles[0]
  // 半隐式欧拉(先更新速度、后用新速度位移):vy = 2 + (-10)*0.1 = 1;
  // py = 0 + 1*0.1 = 0.1
  debug_inspect((p.vy - 1.0).abs() < 0.000001, content="true")
  debug_inspect((p.py - 0.1).abs() < 0.000001, content="true")
  debug_inspect((p.age - 0.1).abs() < 0.000001, content="true")
}

///|
test "粒子 integrate:寿命到判死,活数归零" {
  let ps = @core.ParticleSystem::new(
    4,
    @core.Material::particle(@math3d.Color::white()),
  )
  let _ = ps.spawn(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.3)
  let dt : Double = 0.2
  // 累计 0.6s > 寿命 0.5s
  for _i in 0..<3 {
    ps.integrate(dt)
  }
  debug_inspect(ps.alive_count(), content="0")
  debug_inspect(ps.particles[0].alive, content="false")
}

///|
test "粒子 rebuild_geometry:活粒子四角按公告板轴展开" {
  let ps = @core.ParticleSystem::new(
    4,
    @core.Material::particle(@math3d.Color::white()),
  )
  let _ = ps.spawn(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0)
  ps.rebuild_geometry(@math3d.Vector3::unit_x(), @math3d.Vector3::unit_y())
  let g = ps.geometry
  debug_inspect(g.positions.length(), content="48")
  debug_inspect(g.uvs.length(), content="32")
  debug_inspect(g.indices.length(), content="24")
  // 粒子 0:中心 (1,0,0),尺寸 2 → 左下 (0,-1,0)、右下 (2,-1,0)、
  // 右上 (2,1,0)、左上 (0,1,0)
  debug_inspect(
    (g.positions[0] - 0.0).abs() < 0.000001 &&
    (g.positions[1] + 1.0).abs() < 0.000001 &&
    (g.positions[2] - 0.0).abs() < 0.000001,
    content="true",
  )
  debug_inspect(
    (g.positions[3] - 2.0).abs() < 0.000001 &&
    (g.positions[4] + 1.0).abs() < 0.000001,
    content="true",
  )
  debug_inspect(
    (g.positions[6] - 2.0).abs() < 0.000001 &&
    (g.positions[7] - 1.0).abs() < 0.000001,
    content="true",
  )
  debug_inspect(
    (g.positions[9] - 0.0).abs() < 0.000001 &&
    (g.positions[10] - 1.0).abs() < 0.000001,
    content="true",
  )
  // 未生成的粒子 1 全部折叠在原点(死位初值)
  debug_inspect(
    g.positions[12] == 0.0 && g.positions[13] == 0.0 && g.positions[14] == 0.0,
    content="true",
  )
  debug_inspect(
    g.positions[21] == 0.0 && g.positions[22] == 0.0 && g.positions[23] == 0.0,
    content="true",
  )
  // 索引静态:粒子 1 的四顶点基址 = 4
  debug_inspect(
    g.indices[6] == 4U &&
    g.indices[7] == 5U &&
    g.indices[8] == 6U &&
    g.indices[11] == 7U,
    content="true",
  )
}

///|
test "粒子死亡 → 退化三角形折叠(四顶点同点)" {
  let ps = @core.ParticleSystem::new(
    2,
    @core.Material::particle(@math3d.Color::white()),
  )
  let _ = ps.spawn(3.0, 4.0, 5.0, 0.0, 1.0, 0.0, 0.3, 1.0)
  ps.gravity = 0.0 // 关重力,位移数好口算
  let dt : Double = 0.1
  for _i in 0..<4 {
    ps.step(dt, @math3d.Vector3::unit_x(), @math3d.Vector3::unit_y())
  }
  debug_inspect(ps.alive_count(), content="0")
  let g = ps.geometry
  // 粒子 0 已死:四个顶点 (j=0..3) 全部折叠在同一位置(死亡时位置)
  for j in 0..<4 {
    let x = g.positions[j * 3]
    let y = g.positions[j * 3 + 1]
    let z = g.positions[j * 3 + 2]
    debug_inspect(
      (x - g.positions[0]).abs() < 0.000001 &&
      (y - g.positions[1]).abs() < 0.000001 &&
      (z - g.positions[2]).abs() < 0.000001,
      content="true",
    )
  }
  // 折叠点 = 死亡时刻位置(重力关闭,vy 恒 1:第 3 步 age=0.3 判死,
  // py = 4 + 1.0*0.1*3 = 4.3;第 4 步已死不再积分)
  debug_inspect((g.positions[1] - 4.3).abs() < 0.000001, content="true")
}

///|
test "粒子 spawn:池满拒绝,死位环形复用" {
  let ps = @core.ParticleSystem::new(
    2,
    @core.Material::particle(@math3d.Color::white()),
  )
  debug_inspect(
    ps.spawn(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.1),
    content="true",
  )
  debug_inspect(
    ps.spawn(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.1),
    content="true",
  )
  // 池满
  debug_inspect(
    ps.spawn(2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.1),
    content="false",
  )
  // 第一颗粒子寿终 → 环形扫描找到同一死位(slot 0)
  let dt : Double = 0.5
  for _i in 0..<3 {
    ps.integrate(dt)
  }
  debug_inspect(
    ps.spawn(9.0, 9.0, 9.0, 0.0, 0.0, 0.0, 1.0, 0.1),
    content="true",
  )
  debug_inspect(ps.particles[0].alive, content="true")
  debug_inspect((ps.particles[0].px - 9.0).abs() < 0.000001, content="true")
  debug_inspect(ps.particles[1].alive, content="false")
}

///|
test "粒子 step:integrate+rebuild 组合,阻尼衰减速度" {
  let ps = @core.ParticleSystem::new(
    2,
    @core.Material::particle(@math3d.Color::white()),
  )
  ps.gravity = 0.0
  ps.damping = 0.5
  let _ = ps.spawn(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 10.0, 0.5)
  // dt=0.1 → damp = 1-(1-0.5)*0.1 = 0.95
  ps.step(0.1, @math3d.Vector3::unit_x(), @math3d.Vector3::unit_y())
  let p = ps.particles[0]
  debug_inspect((p.vx - 0.95).abs() < 0.000001, content="true")
  debug_inspect((p.px - 0.095).abs() < 0.000001, content="true")
  // 几何同步:活粒子四角展开,中心在 (0.095, 0, 0)
  let g = ps.geometry
  debug_inspect(
    (g.positions[3] - 0.095 - 0.25).abs() < 0.000001,
    content="true",
  )
}

///|
test "粒子系统节点:mesh 材质 kind=4,几何可被渲染层读取" {
  let ps = @core.ParticleSystem::new(
    6,
    @core.Material::particle(@math3d.Color::white()),
  )
  let m = ps.obj.mesh.unwrap()
  debug_inspect(m.material.is_particle(), content="true")
  debug_inspect(m.geometry.vertex_count(), content="24")
}
