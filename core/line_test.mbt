// core 包测试:Line/LineSegments 几何构建与运行时更新(A7)。

///|
test "Line::from_positions:位置数组构建,拓扑与 LineBasic 材质默认值" {
  let mat = @core.Material::line_basic(@math3d.Color::red())
  let line = @core.Line::from_positions(
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0],
    mat,
  )
  let m = line.mesh.unwrap()
  debug_inspect(m.geometry.vertex_count(), content="3")
  // 非索引化:索引空
  debug_inspect(m.geometry.index_count(), content="0")
  // Line = 折线条带拓扑
  debug_inspect(m.topology, content="1")
  debug_inspect(mat.is_line_basic(), content="true")
  debug_inspect(mat.kind, content="5")
  // 线材质不受光照
  debug_inspect(mat.lit(), content="false")
  debug_inspect(mat.color.equals(@math3d.Color::red()), content="true")
  // 默认无顶点色
  debug_inspect(m.geometry.colors.length(), content="0")
  debug_inspect(mat.vertex_colors, content="false")
}

///|
test "Line::from_positions:顶点色可选,入几何并开材质 vertex_colors" {
  let mat = @core.Material::line_basic(@math3d.Color::white())
  let line = @core.Line::from_positions([0.0, 0.0, 0.0, 1.0, 0.0, 0.0], mat, colors=[
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  ])
  let m = line.mesh.unwrap()
  debug_inspect(m.geometry.colors.length(), content="6")
  debug_inspect(mat.vertex_colors, content="true")
}

///|
test "LineSegments::from_positions:线段对拓扑" {
  let mat = @core.Material::line_basic(
    @math3d.Color::from_hex("#8899aa").unwrap(),
  )
  let seg = @core.LineSegments::from_positions(
    [-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
    mat,
  )
  let m = seg.mesh.unwrap()
  // 2 档线段 = 4 顶点
  debug_inspect(m.geometry.vertex_count(), content="4")
  debug_inspect(m.topology, content="2")
}

///|
test "Line::new:显式几何带索引,索引保留;节点可挂场景遍历可见" {
  // 闭合折线:3 顶点 + 索引 0,1,2,0(末段回起点)
  let geo = @core.BufferGeometry::from_positions([
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 1.0, 0.0,
  ])
  geo.indices.push(0U)
  geo.indices.push(1U)
  geo.indices.push(2U)
  geo.indices.push(0U)
  let line = @core.Line::new(
    geo,
    @core.Material::line_basic(@math3d.Color::green()),
  )
  debug_inspect(line.mesh.unwrap().geometry.index_count(), content="4")
  let scene = @core.Scene::new()
  scene.add(line)
  let mut visited = 0
  scene.root.traverse(fn(_o) {
    visited = visited + 1
    true
  })
  debug_inspect(visited, content="2")
}

///|
test "set_positions:等长更新(动态折线每帧改端点的路径)" {
  let line = @core.Line::from_positions(
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    @core.Material::line_basic(@math3d.Color::from_hex("#00ffff").unwrap()),
  )
  let geo = line.mesh.unwrap().geometry
  geo.set_positions([0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
  debug_inspect(geo.vertex_count(), content="2")
  debug_inspect(
    geo.positions[0] == 0.0 && geo.positions[5] == 5.0,
    content="true",
  )
}

///|
test "set_positions:变长更新,顶点数随新数组" {
  let line = @core.Line::from_positions(
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 2.0, 0.0, 0.0],
    @core.Material::line_basic(@math3d.Color::from_hex("#00ffff").unwrap()),
  )
  let geo = line.mesh.unwrap().geometry
  geo.set_positions([0.0, 0.0, 0.0, 1.0, 1.0, 1.0])
  debug_inspect(geo.vertex_count(), content="2")
  geo.set_positions([])
  debug_inspect(geo.vertex_count(), content="0")
}

///|
test "set_vertex:单顶点更新,越界静默忽略" {
  let line = @core.Line::from_positions(
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    @core.Material::line_basic(@math3d.Color::from_hex("#00ffff").unwrap()),
  )
  let geo = line.mesh.unwrap().geometry
  geo.set_vertex(1, 7.0, 8.0, 9.0)
  debug_inspect(
    geo.positions[3] == 7.0 &&
    geo.positions[4] == 8.0 &&
    geo.positions[5] == 9.0,
    content="true",
  )
  // 首顶点不被波及
  debug_inspect(
    geo.positions[0] == 0.0 && geo.positions[1] == 0.0,
    content="true",
  )
  // 越界(负与超尾)不抛不改
  geo.set_vertex(-1, 99.0, 99.0, 99.0)
  geo.set_vertex(2, 99.0, 99.0, 99.0)
  debug_inspect(
    geo.positions[0] == 0.0 && geo.positions[5] == 9.0,
    content="true",
  )
}

///|
test "set_colors:顶点色运行时替换" {
  let line = @core.Line::from_positions(
    [0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    @core.Material::line_basic(@math3d.Color::white()),
    colors=[1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  )
  let geo = line.mesh.unwrap().geometry
  geo.set_colors([1.0, 0.0, 0.0, 0.0, 0.0, 1.0])
  debug_inspect(geo.colors.length(), content="6")
  debug_inspect(geo.colors[0] == 1.0 && geo.colors[1] == 0.0, content="true")
  debug_inspect(geo.colors[5] == 1.0, content="true")
}
