// geometries 包黑盒测试:与 three.js 参照实现逐数值核对(公式、常数、边界分支)。

///| 浮点近似相等辅助(1e-9)
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.000000001
}

///|
test "cylinder(5,5,20,32,1) 拓扑:66 侧面顶点 + 上下端盖 65×2,索引 384" {
  let g = @geometries.cylinder(
    5.0, 5.0, 20.0, 32, 1, false, 0.0, 6.283185307179586,
  )
  debug_inspect(g.positions.length(), content="588")
  debug_inspect(g.normals.length(), content="588")
  debug_inspect(g.uvs.length(), content="392")
  debug_inspect(g.indices.length(), content="384")
}

///|
test "cylinder 侧面数值:顶点/法线/uv/索引首三角" {
  let g = @geometries.cylinder(
    5.0, 5.0, 20.0, 32, 1, false, 0.0, 6.283185307179586,
  )
  // 顶点 0:theta=0 → (0, 10, 5),normal = normalize(0,0,1),uv = (0,1)
  debug_inspect(
    close(g.positions[0], 0.0) &&
    close(g.positions[1], 10.0) &&
    close(g.positions[2], 5.0),
    content="true",
  )
  debug_inspect(
    close(g.normals[0], 0.0) && close(g.normals[1], 0.0) && close(g.normals[2], 1.0),
    content="true",
  )
  debug_inspect(close(g.uvs[0], 0.0) && close(g.uvs[1], 1.0), content="true")
  // 顶点 33(底行 x=0):(0, -10, 5),uv = (0, 0)
  debug_inspect(
    close(g.positions[99], 0.0) &&
    close(g.positions[100], -10.0) &&
    close(g.positions[101], 5.0),
    content="true",
  )
  debug_inspect(close(g.uvs[66], 0.0) && close(g.uvs[67], 0.0), content="true")
  // 首三角 a,b,d = 0,33,1
  debug_inspect(g.indices[0] == 0U, content="true")
  debug_inspect(g.indices[1] == 33U, content="true")
  debug_inspect(g.indices[2] == 1U, content="true")
}

///|
test "cylinder 端盖:中心顶点 normal=(0,±1,0)、uv=(0.5,0.5)、扇面索引" {
  let g = @geometries.cylinder(
    5.0, 5.0, 20.0, 32, 1, false, 0.0, 6.283185307179586,
  )
  // 顶点 66 = 顶盖首中心顶点
  debug_inspect(
    close(g.positions[198], 0.0) &&
    close(g.positions[199], 10.0) &&
    close(g.positions[200], 0.0),
    content="true",
  )
  debug_inspect(
    close(g.normals[198], 0.0) &&
    close(g.normals[199], 1.0) &&
    close(g.normals[200], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[132], 0.5) && close(g.uvs[133], 0.5), content="true")
  // torso 192 索引后,顶盖首扇面 (i, i+1, c) = (98, 99, 66)
  debug_inspect(g.indices[192] == 98U, content="true")
  debug_inspect(g.indices[193] == 99U, content="true")
  debug_inspect(g.indices[194] == 66U, content="true")
}

///|
test "cone(1,1,4,1,open):顶半径 0 裁剪顶行三角,只余 b,c,d" {
  let g = @geometries.cone(
    1.0, 1.0, 4, 1, true, 0.0, 6.283185307179586,
  )
  debug_inspect(g.positions.length(), content="30")
  debug_inspect(g.uvs.length(), content="20")
  debug_inspect(g.indices.length(), content="12")
  // 顶点 0(尖):radius=0 → (0, 0.5, 0)
  debug_inspect(
    close(g.positions[0], 0.0) &&
    close(g.positions[1], 0.5) &&
    close(g.positions[2], 0.0),
    content="true",
  )
  // 顶点 5(底行 x=0):(0, -0.5, 1)
  debug_inspect(
    close(g.positions[15], 0.0) &&
    close(g.positions[16], -0.5) &&
    close(g.positions[17], 1.0),
    content="true",
  )
  // 底行法线:normalize(0, slope=1, 1) = (0, √2/2, √2/2)
  debug_inspect(
    close(g.normals[15], 0.0) &&
    close(g.normals[16], 0.7071067811865476) &&
    close(g.normals[17], 0.7071067811865476),
    content="true",
  )
  // 首三角 b,c,d = 5,6,1
  debug_inspect(g.indices[0] == 5U, content="true")
  debug_inspect(g.indices[1] == 6U, content="true")
  debug_inspect(g.indices[2] == 1U, content="true")
}

///|
test "sphere(1,4,2) 拓扑与极点 uv 偏移" {
  let g = @geometries.sphere(
    1.0, 4, 2, 0.0, 6.283185307179586, 0.0, 3.141592653589793,
  )
  debug_inspect(g.positions.length(), content="45")
  debug_inspect(g.uvs.length(), content="30")
  // iy=0 只出 b,c,d;iy=1(=height-1,thetaEnd=π)只出 a,b,d → 8 三角
  debug_inspect(g.indices.length(), content="24")
  // 顶点 0(北极):theta=0 → (0,1,0),uv=(0+0.5/4, 1)
  debug_inspect(
    close(g.positions[0], 0.0) &&
    close(g.positions[1], 1.0) &&
    close(g.positions[2], 0.0),
    content="true",
  )
  debug_inspect(
    close(g.normals[0], 0.0) &&
    close(g.normals[1], 1.0) &&
    close(g.normals[2], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[0], 0.125) && close(g.uvs[1], 1.0), content="true")
  // 顶点 5(赤道 ix=0):(-1,0,0),uv=(0,0.5)
  debug_inspect(
    close(g.positions[15], -1.0) &&
    close(g.positions[16], 0.0) &&
    close(g.positions[17], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[10], 0.0) && close(g.uvs[11], 0.5), content="true")
  // 顶点 10(南极):(0,-1,0),uv=(-0.125, 0)
  debug_inspect(
    close(g.positions[30], 0.0) &&
    close(g.positions[31], -1.0) &&
    close(g.positions[32], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[20], -0.125) && close(g.uvs[21], 0.0), content="true")
  // 首三角 b,c,d = 0,5,6;iy=1 首三角 a,b,d = 6,5,11
  debug_inspect(
    g.indices[0] == 0U && g.indices[1] == 5U && g.indices[2] == 6U,
    content="true",
  )
  debug_inspect(
    g.indices[12] == 6U && g.indices[13] == 5U && g.indices[14] == 11U,
    content="true",
  )
}

///|
test "sphere 段数下限钳制:width<3 → 3、height<2 → 2" {
  let g = @geometries.sphere(
    1.0, 1, 1, 0.0, 6.283185307179586, 0.0, 3.141592653589793,
  )
  // 3×2 钳制后顶点 3 行 × 4 列 = 12
  debug_inspect(g.positions.length(), content="36")
  debug_inspect(g.uvs.length(), content="24")
}

///|
test "circle(1,4,0,π/2) 扇形数值" {
  let g = @geometries.circle(
    1.0, 4, 0.0, 1.5707963267948966,
  )
  debug_inspect(g.positions.length(), content="18")
  debug_inspect(g.uvs.length(), content="12")
  debug_inspect(g.indices.length(), content="12")
  // 顶点 1:s=0 → (1, 0, 0)
  debug_inspect(
    close(g.positions[3], 1.0) &&
    close(g.positions[4], 0.0) &&
    close(g.positions[5], 0.0),
    content="true",
  )
  // 法线全 (0,0,1)
  debug_inspect(
    close(g.normals[3], 0.0) &&
    close(g.normals[4], 0.0) &&
    close(g.normals[5], 1.0),
    content="true",
  )
  // 顶点 2:s=1 → π/8:(cos π/8, sin π/8, 0),uv = ((x/r+1)/2, (y/r+1)/2)
  debug_inspect(
    close(g.positions[6], 0.9238795325112867) &&
    close(g.positions[7], 0.3826834323650898) &&
    close(g.positions[8], 0.0),
    content="true",
  )
  debug_inspect(
    close(g.uvs[4], 0.9619397662556434) &&
    close(g.uvs[5], 0.6913417161825449),
    content="true",
  )
  // 顶点 5:s=4 → π/2:(0, 1, 0)
  debug_inspect(
    close(g.positions[15], 0.0) &&
    close(g.positions[16], 1.0) &&
    close(g.positions[17], 0.0),
    content="true",
  )
  // 索引:(i, i+1, 0),i = 1..4
  debug_inspect(
    g.indices[0] == 1U &&
    g.indices[1] == 2U &&
    g.indices[2] == 0U &&
    g.indices[9] == 4U &&
    g.indices[10] == 5U &&
    g.indices[11] == 0U,
    content="true",
  )
}

///|
test "circle 段数下限钳制:segments=2 → 3" {
  let g = @geometries.circle(
    1.0, 2, 0.0, 6.283185307179586,
  )
  // 中心 + 4 边 = 5 顶点
  debug_inspect(g.positions.length(), content="15")
}

///|
test "torus(1,0.4,3,4,π) 拓扑与数值" {
  let g = @geometries.torus(
    1.0, 0.4, 3, 4, 3.141592653589793, 0.0, 6.283185307179586,
  )
  debug_inspect(g.positions.length(), content="60")
  debug_inspect(g.uvs.length(), content="40")
  debug_inspect(g.indices.length(), content="72")
  // 顶点 0(j=0,i=0):v=0,u=0 → (1.4, 0, 0),normal=(1,0,0),uv=(0,0)
  debug_inspect(
    close(g.positions[0], 1.4) &&
    close(g.positions[1], 0.0) &&
    close(g.positions[2], 0.0),
    content="true",
  )
  debug_inspect(
    close(g.normals[0], 1.0) &&
    close(g.normals[1], 0.0) &&
    close(g.normals[2], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[0], 0.0) && close(g.uvs[1], 0.0), content="true")
  // 顶点 1(j=0,i=1):u=π/4 → (1.4cos45°, 1.4sin45°, 0),normal=(cos45°, sin45°, 0),uv=(0.25, 0)
  debug_inspect(
    close(g.positions[3], 0.9899494936611666) &&
    close(g.positions[4], 0.9899494936611666) &&
    close(g.positions[5], 0.0),
    content="true",
  )
  debug_inspect(
    close(g.normals[3], 0.7071067811865476) &&
    close(g.normals[4], 0.7071067811865476) &&
    close(g.normals[5], 0.0),
    content="true",
  )
  debug_inspect(close(g.uvs[2], 0.25) && close(g.uvs[3], 0.0), content="true")
  // 顶点 5(j=1,i=0):v=2π/3 → (0.8, 0, 0.4·sin(2π/3)),normal=(-0.5, 0, sin(2π/3)),uv=(0, 1/3)
  debug_inspect(
    close(g.positions[15], 0.8) &&
    close(g.positions[16], 0.0) &&
    close(g.positions[17], 0.34641016151377546),
    content="true",
  )
  debug_inspect(
    close(g.normals[15], -0.5) &&
    close(g.normals[16], 0.0) &&
    close(g.normals[17], 0.8660254037844386),
    content="true",
  )
  debug_inspect(close(g.uvs[10], 0.0) && close(g.uvs[11], 0.3333333333333333), content="true")
  // 首四边形(j=1,i=1):a=5,b=0,d=6 然后 b,c,d = 0,1,6
  debug_inspect(
    g.indices[0] == 5U &&
    g.indices[1] == 0U &&
    g.indices[2] == 6U &&
    g.indices[3] == 0U &&
    g.indices[4] == 1U &&
    g.indices[5] == 6U,
    content="true",
  )
}

///|
test "core 既有几何生成 uv(three.js 同布局;空几何无)" {
  // box:24 顶点 ×2 = 48;plane:4 顶点 ×2 = 8(A1 起带贴图管线,UV 必备)
  debug_inspect(@core.BufferGeometry::box(1.0, 1.0, 1.0).uvs.length(), content="48")
  debug_inspect(@core.BufferGeometry::plane(2.0, 2.0).uvs.length(), content="8")
  debug_inspect(@core.BufferGeometry::empty().uvs.length(), content="0")
  // 顶点色属性:生成器不产出,留空由管线层补白
  debug_inspect(@core.BufferGeometry::box(1.0, 1.0, 1.0).colors.length(), content="0")
}
