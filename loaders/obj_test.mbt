// loaders 包黑盒测试:OBJ 解析语义对照 three.js OBJLoader。

///|
test "OBJ: 四种面格式解析(f、f v/vt、f v//vn、f v/vt/vn)" {
  let text = "v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\n" +
    "vt 0 0\nvt 1 0\nvt 0 1\n" +
    "vn 1 0 0\nvn 0 1 0\nvn 0 0 1\nvn -1 -1 -1\n" +
    "f 1 2 3\n" +
    "f 2/1 4/2 3/3\n" +
    "f 1//4 2//1 4//3\n" +
    "f 3/3/2 4/2/3 1/1/4\n"
  let r = @loaders.parse_obj_detailed(text)
  debug_inspect(r.skipped_lines, content="0")
  // 4 面 ×3 顶点直接展开,索引为顺序号
  debug_inspect(r.geometry.vertex_count(), content="12")
  debug_inspect(r.geometry.index_count(), content="12")
  debug_inspect(r.geometry.indices.length(), content="12")
  debug_inspect(r.geometry.indices[11], content="11")
  // 法线与位置逐顶点对齐;uv 因有 vt 引用而输出
  debug_inspect(
    r.geometry.normals.length() == r.geometry.positions.length(),
    content="true",
  )
  debug_inspect(r.geometry.uvs.length(), content="24")
  // 第一个面 f 1 2 3 无 vn → 面法线 (C-B)×(A-B) = (0,0,1)
  debug_inspect(
    r.geometry.normals[2] - 1.0 < 0.000001 &&
    r.geometry.normals[0].abs() < 0.000001 &&
    r.geometry.normals[1].abs() < 0.000001,
    content="true",
  )
  // 第三个面 f 1//4 2//1 4//3 用 vn 表:第 4 个 vn=(-1,-1,-1)
  debug_inspect(
    (r.geometry.normals[18] + 1.0).abs() < 0.000001 &&
    (r.geometry.normals[19] + 1.0).abs() < 0.000001 &&
    (r.geometry.normals[20] + 1.0).abs() < 0.000001,
    content="true",
  )
  // 第四个面 f 3/3/2:uv 取 vt[2]=(0,1)、位置取 v[2]=(0,1,0)
  debug_inspect(
    r.geometry.uvs[6] == 0.0 &&
    r.geometry.uvs[7] - 1.0 < 0.000001 &&
    r.geometry.positions[27] - 1.0 < 0.000001,
    content="true",
  )
}

///|
test "OBJ: 任意多边形扇形三角化(五边面 → 3 个三角形)" {
  let text = "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nv -0.5 0.5 0\nf 1 2 3 4 5\n"
  let g = @loaders.parse_obj(text)
  debug_inspect(g.vertex_count(), content="9")
  debug_inspect(g.index_count(), content="9")
  // 扇形:三角 (v1,v2,v3)(v1,v3,v4)(v1,v4,v5),首顶点都是 v1=(0,0,0)
  debug_inspect(
    g.positions[0] == 0.0 && g.positions[9] == 0.0 && g.positions[18] == 0.0,
    content="true",
  )
  // 第二个三角形第二顶点是 v3=(1,1,0)
  debug_inspect(
    g.positions[12] - 1.0 < 0.000001 && g.positions[13] - 1.0 < 0.000001,
    content="true",
  )
}

///|
test "OBJ: 负索引从已解析末尾倒数" {
  let text = "v 0 0 0\nv 1 0 0\nv 0 1 0\nv 9 9 9\nf -4 -3 -2\n"
  let g = @loaders.parse_obj(text)
  // -4/-3/-2 → 顶点 1/2/3 = (0,0,0)(1,0,0)(0,1,0)
  debug_inspect(
    g.positions[3] - 1.0 < 0.000001 &&
    g.positions[4] == 0.0 &&
    g.positions[5] == 0.0 &&
    g.positions[6] == 0.0 &&
    g.positions[7] - 1.0 < 0.000001,
    content="true",
  )
}

///|
test "OBJ: 坏行容错跳过并计数" {
  let text = "v 1 2 3\n" +
    "v x y z\n" + // 数字非法
    "f 1 1 1\n" + // 退化三角形合法(法线零向量)
    "f 99 1 2\n" + // 索引越界
    "f 1 2\n" + // 顶点数不足
    "garbage line here\n" + // 未知指令
    "l 1 2\n" + // 线指令不支持
    "# 注释不计\n" +
    "\n" +
    "o cube\n" + // 分组指令认识不产生几何
    "s off\n" +
    "usemtl mat\n" +
    "mtllib a.mtl\n"
  let r = @loaders.parse_obj_detailed(text)
  debug_inspect(r.skipped_lines, content="5")
  // 合法面 f 1 1 1 输出 3 顶点
  debug_inspect(r.geometry.vertex_count(), content="3")
}

///|
test "OBJ: CRLF 归一与反斜杠续行" {
  let text = "v 1 0 0\r\nv 0 1 \\\n0\nf 1 2 1\n"
  // 第二行是 "v 0 1 \" + "\n" + "0" → 续行拼接成 "v 0 1 0"
  let g = @loaders.parse_obj(text)
  debug_inspect(g.vertex_count(), content="3")
  debug_inspect(
    g.positions[3] == 0.0 &&
    g.positions[4] - 1.0 < 0.000001 &&
    g.positions[5] == 0.0,
    content="true",
  )
}

///|
test "OBJ: 无 vt 引用时 uvs 不输出(three.js hasUVIndices 语义)" {
  let text = "v 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0 0\nf 1 2 3\n"
  let g = @loaders.parse_obj(text)
  debug_inspect(g.uvs.length(), content="0")
  // 反例:f 引用 vt 后输出
  let text2 = "v 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0.5 0.5\nf 1/1 2/1 3/1\n"
  let g2 = @loaders.parse_obj(text2)
  debug_inspect(g2.uvs.length(), content="6")
  debug_inspect(g2.uvs[0] - 0.5 < 0.000001, content="true")
}

///|
test "OBJ: v 行带顶点色列(第 5-7 列)忽略不干扰坐标" {
  let text = "v 1 2 3 0.5 0.5 0.5\nv 4 5 6\nv 7 8 9\nf 1 2 3\n"
  let g = @loaders.parse_obj(text)
  debug_inspect(g.positions[3] - 4.0 < 0.000001, content="true")
}

///|
test "OBJ: 八面体全量解析(8 个三角面,内置示例同款数据)" {
  let text = "v 1 0 0\nv -1 0 0\nv 0 1 0\nv 0 -1 0\nv 0 0 1\nv 0 0 -1\n" +
    "f 1 3 5\nf 5 3 2\nf 2 3 6\nf 6 3 1\n" +
    "f 5 4 1\nf 2 4 5\nf 6 4 2\nf 1 4 6\n"
  let g = @loaders.parse_obj(text)
  debug_inspect(g.vertex_count(), content="24")
  debug_inspect(g.index_count(), content="24")
  // 面法线外向:第一面 (1,3,5) 法线为 (1,1,1)/√3
  let s = 1.0 / 3.0.sqrt()
  debug_inspect(
    r0_abs(g.normals[0], s) < 0.000001 &&
    r0_abs(g.normals[1], s) < 0.000001 &&
    r0_abs(g.normals[2], s) < 0.000001,
    content="true",
  )
}

///|
/// 数值近似比较
fn r0_abs(a : Double, b : Double) -> Double {
  (a - b).abs()
}
