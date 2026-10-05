// renderers 包测试:线管线的纯编码函数(顶点色补白与 f32 字节编码)。

///|
test "line_color_bytes:几何无顶点色 → 补 f32 白(乘法恒等)" {
  let geo = @core.BufferGeometry::from_positions([0.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  let b = line_color_bytes(geo)
  // 2 顶点 × 3 分量 × 4 字节
  debug_inspect(b.length(), content="24")
  // f32 1.0 = 0x3F800000,小端 [00 00 80 3F]
  debug_inspect(
    b[0] == b'\x00' && b[1] == b'\x00' && b[2] == b'\x80' && b[3] == b'\x3f',
    content="true",
  )
  // 逐字节重复到末尾
  debug_inspect(
    b[20] == b'\x00' && b[21] == b'\x00' && b[22] == b'\x80' && b[23] == b'\x3f',
    content="true",
  )
}

///|
test "line_color_bytes:几何带顶点色 → 原样 f32 编码" {
  let geo = @core.BufferGeometry::from_positions([0.0, 0.0, 0.0])
  geo.set_colors([0.5, 0.25, 1.0])
  let b = line_color_bytes(geo)
  debug_inspect(b.length(), content="12")
  // 0.5 = 0x3F000000 → [00 00 00 3F]
  debug_inspect(
    b[0] == b'\x00' && b[1] == b'\x00' && b[2] == b'\x00' && b[3] == b'\x3f',
    content="true",
  )
  // 0.25 = 0x3E800000 → [00 00 80 3E]
  debug_inspect(
    b[4] == b'\x00' && b[5] == b'\x00' && b[6] == b'\x80' && b[7] == b'\x3e',
    content="true",
  )
  // 1.0 → [00 00 80 3F]
  debug_inspect(
    b[8] == b'\x00' && b[9] == b'\x00' && b[10] == b'\x80' && b[11] == b'\x3f',
    content="true",
  )
}

///|
test "line_color_bytes:colors 长度与顶点数失配 → 按补白处理" {
  // 2 顶点只给 3 分量(残缺)→ 不采用,补白
  let geo = @core.BufferGeometry::from_positions([0.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  geo.set_colors([0.0, 0.0, 0.0])
  let b = line_color_bytes(geo)
  debug_inspect(b.length(), content="24")
  debug_inspect(b[3] == b'\x3f' && b[23] == b'\x3f', content="true")
}

///|
test "f32x3_bytes:单顶点 xyz 小端编码" {
  let b = f32x3_bytes(1.0, -2.0, 0.5)
  debug_inspect(b.length(), content="12")
  // 1.0 = 0x3F800000 → [00 00 80 3F]
  debug_inspect(
    b[0] == b'\x00' && b[1] == b'\x00' && b[2] == b'\x80' && b[3] == b'\x3f',
    content="true",
  )
  // -2.0 = 0xC0000000 → [00 00 00 C0]
  debug_inspect(
    b[4] == b'\x00' && b[5] == b'\x00' && b[6] == b'\x00' && b[7] == b'\xc0',
    content="true",
  )
  // 0.5 = 0x3F000000 → [00 00 00 3F]
  debug_inspect(
    b[8] == b'\x00' && b[9] == b'\x00' && b[10] == b'\x00' && b[11] == b'\x3f',
    content="true",
  )
}
