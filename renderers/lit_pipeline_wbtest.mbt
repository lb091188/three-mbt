// renderers 包白盒测试:光照 uniform 编码偏移(布局与 lit_wgsl struct 对齐)。

///| 从字节序列按小端读回 f32
fn read_f32_at(bs : Bytes, off : Int) -> Double {
  let bits = bs[off].to_uint() |
    (bs[off + 1].to_uint() << 8) |
    (bs[off + 2].to_uint() << 16) |
    (bs[off + 3].to_uint() << 24)
  Float::reinterpret_from_uint(bits).to_double()
}

test "lit_uniform_bytes:总长与矩阵/相机/材质偏移" {
  let identity = @math3d.Matrix4::identity()
  let material = @core.Material::lambert(
    @math3d.Color::red(),
    @math3d.Color::black(),
  )
  let ub = lit_uniform_bytes(
    identity,
    identity,
    identity,
    @math3d.Vector3::new(1.0, 2.0, 3.0),
    material,
    @core.SceneLights::empty(),
  )
  debug_inspect(ub.length() == 416, content="true")
  debug_inspect(lit_uniform_size == 416UL, content="true")
  // mvp(0)与 model(64)单位阵:m11=1、m12=0
  debug_inspect(read_f32_at(ub, 0) == 1.0, content="true")
  debug_inspect(read_f32_at(ub, 4) == 0.0, content="true")
  debug_inspect(read_f32_at(ub, 64) == 1.0, content="true")
  // 相机位置偏移 192
  debug_inspect(read_f32_at(ub, 192) == 1.0, content="true")
  debug_inspect(read_f32_at(ub, 196) == 2.0, content="true")
  debug_inspect(read_f32_at(ub, 200) == 3.0, content="true")
  // 漫反射色偏移 208(Lambert 红)
  debug_inspect(read_f32_at(ub, 208) == 1.0, content="true")
  debug_inspect(read_f32_at(ub, 212) == 0.0, content="true")
  // 材质参数偏移 256:shininess=30、kind=1(Lambert)
  debug_inspect(read_f32_at(ub, 256) == 30.0, content="true")
  debug_inspect(read_f32_at(ub, 260) == 1.0, content="true")
}

test "lit_uniform_bytes:Phong 的 kind=2 与高光参数" {
  let identity = @math3d.Matrix4::identity()
  let material = @core.Material::phong(
    @math3d.Color::white(),
    @math3d.Color::from_hex("#9ad7f0").unwrap(),
    48.0,
    @math3d.Color::black(),
  )
  let ub = lit_uniform_bytes(
    identity,
    identity,
    identity,
    @math3d.Vector3::zero(),
    material,
    @core.SceneLights::empty(),
  )
  debug_inspect(read_f32_at(ub, 256) == 48.0, content="true")
  debug_inspect(read_f32_at(ub, 260) == 2.0, content="true")
  // 高光色偏移 240
  let spec = @math3d.Color::from_hex("#9ad7f0").unwrap()
  debug_inspect(
    (read_f32_at(ub, 240) - spec.r).abs() < 0.0000001,
    content="true",
  )
  debug_inspect(
    (read_f32_at(ub, 244) - spec.g).abs() < 0.0000001,
    content="true",
  )
  debug_inspect(
    (read_f32_at(ub, 248) - spec.b).abs() < 0.0000001,
    content="true",
  )
}

test "lit_uniform_bytes:灯光段偏移、强度乘法与启用位" {
  let identity = @math3d.Matrix4::identity()
  let material = @core.Material::lambert(
    @math3d.Color::white(),
    @math3d.Color::black(),
  )
  let empty = lit_uniform_bytes(
    identity,
    identity,
    identity,
    @math3d.Vector3::zero(),
    material,
    @core.SceneLights::empty(),
  )
  // 无灯光:各段启用位(w 分量)皆为 0
  debug_inspect(read_f32_at(empty, 284) == 0.0, content="true")
  debug_inspect(read_f32_at(empty, 300) == 0.0, content="true")
  debug_inspect(read_f32_at(empty, 332) == 0.0, content="true")
  debug_inspect(read_f32_at(empty, 396) == 0.0, content="true")
  let lights : @core.SceneLights = {
    ambient: Some({
      color: @math3d.Color::new(0.25, 0.5, 0.75),
      intensity: 2.0,
    }),
    directional: Some({
      direction: @math3d.Vector3::new(0.0, 1.0, 0.0),
      color: @math3d.Color::white(),
      intensity: 3.0,
    }),
    point: Some({
      position: @math3d.Vector3::new(1.0, 2.0, 3.0),
      color: @math3d.Color::red(),
      intensity: 4.0,
      distance: 10.0,
      decay: 2.0,
    }),
    hemisphere: Some({
      sky_color: @math3d.Color::new(0.3, 0.6, 1.2),
      ground_color: @math3d.Color::new(0.2, 0.2, 0.1),
    }),
  }
  let ub = lit_uniform_bytes(
    identity,
    identity,
    identity,
    @math3d.Vector3::zero(),
    material,
    lights,
  )
  // 半球光:天色 384(w=启用)、地色 400(f32 往返带容差)
  debug_inspect((read_f32_at(ub, 384) - 0.3).abs() < 0.0001, content="true")
  debug_inspect((read_f32_at(ub, 388) - 0.6).abs() < 0.0001, content="true")
  debug_inspect(read_f32_at(ub, 396) == 1.0, content="true")
  debug_inspect((read_f32_at(ub, 400) - 0.2).abs() < 0.0001, content="true")
  // 环境光偏移 272:rgb=color*intensity,w=启用
  debug_inspect(read_f32_at(ub, 272) == 0.5, content="true")
  debug_inspect(read_f32_at(ub, 276) == 1.0, content="true")
  debug_inspect(read_f32_at(ub, 280) == 1.5, content="true")
  debug_inspect(read_f32_at(ub, 284) == 1.0, content="true")
  // 方向光偏移 288/304
  debug_inspect(read_f32_at(ub, 292) == 1.0, content="true")
  debug_inspect(read_f32_at(ub, 304) == 3.0, content="true")
  debug_inspect(read_f32_at(ub, 308) == 3.0, content="true")
  debug_inspect(read_f32_at(ub, 312) == 3.0, content="true")
  // 点光偏移 320/336/352
  debug_inspect(read_f32_at(ub, 324) == 2.0, content="true")
  debug_inspect(read_f32_at(ub, 336) == 4.0, content="true")
  debug_inspect(read_f32_at(ub, 352) == 10.0, content="true")
  debug_inspect(read_f32_at(ub, 356) == 2.0, content="true")
}

test "write_matrix4:列主序连续写入" {
  let b : FixedArray[Byte] = FixedArray::make(72, b'0')
  let m = @math3d.Matrix4::from_array([
    1.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 4.0, 5.0, 6.0, 1.0,
  ])
  write_matrix4(b, 8, m)
  let bs = to_bytes(b)
  debug_inspect(read_f32_at(bs, 8) == 1.0, content="true")
  debug_inspect(read_f32_at(bs, 8 + 20) == 2.0, content="true")
  debug_inspect(read_f32_at(bs, 8 + 40) == 3.0, content="true")
  debug_inspect(read_f32_at(bs, 8 + 48) == 4.0, content="true")
}
