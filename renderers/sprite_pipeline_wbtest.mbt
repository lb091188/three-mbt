// renderers 包白盒测试:A8 公告板 uniform 编码偏移(布局与 sprite_wgsl
// struct 对齐:0 vp / 64 center / 80 axis_x / 96 axis_y / 112 axis_z /
// 128 params / 144 color)。

///|
/// 从字节序列按小端读回 f32
fn read_sprite_f32_at(bs : Bytes, off : Int) -> Double {
  let bits = bs[off].to_uint() |
    (bs[off + 1].to_uint() << 8) |
    (bs[off + 2].to_uint() << 16) |
    (bs[off + 3].to_uint() << 24)
  Float::reinterpret_from_uint(bits).to_double()
}

///|
test "sprite_uniform_bytes:总长 160 与各段偏移" {
  let identity = @math3d.Matrix4::identity()
  let ub = sprite_uniform_bytes(
    identity,
    @math3d.Vector3::new(1.0, 2.0, 3.0),
    @math3d.Vector3::new(2.0, 0.0, 0.0),
    @math3d.Vector3::new(0.0, 4.0, 0.0),
    @math3d.Vector3::new(0.0, 0.0, 1.0),
    1.5707963267948966,
    @math3d.Color::new(0.25, 0.5, 0.75),
    0.8,
  )
  debug_inspect(ub.length() == 160, content="true")
  debug_inspect(sprite_uniform_size == 160UL, content="true")
  // vp 单位阵:m11=1(偏移 0),m12=0(偏移 4)
  debug_inspect(read_sprite_f32_at(ub, 0) == 1.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 4) == 0.0, content="true")
  // center 偏移 64
  debug_inspect(read_sprite_f32_at(ub, 64) == 1.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 68) == 2.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 72) == 3.0, content="true")
  // axis_x 偏移 80 = (2,0,0)
  debug_inspect(read_sprite_f32_at(ub, 80) == 2.0, content="true")
  // axis_y 偏移 96 = (0,4,0)
  debug_inspect(read_sprite_f32_at(ub, 100) == 4.0, content="true")
  // axis_z 偏移 112 = (0,0,1)
  debug_inspect(read_sprite_f32_at(ub, 120) == 1.0, content="true")
  // params 偏移 128:x=rotation,y=opacity
  debug_inspect(
    (read_sprite_f32_at(ub, 128) - 1.5707963267948966).abs() < 0.000001,
    content="true",
  )
  // 0.8 非 f32 精确可表,带容差
  debug_inspect(
    (read_sprite_f32_at(ub, 132) - 0.8).abs() < 0.000001,
    content="true",
  )
  // color 偏移 144:rgb 着色,a=opacity
  debug_inspect(read_sprite_f32_at(ub, 144) == 0.25, content="true")
  debug_inspect(read_sprite_f32_at(ub, 148) == 0.5, content="true")
  debug_inspect(read_sprite_f32_at(ub, 152) == 0.75, content="true")
  debug_inspect(
    (read_sprite_f32_at(ub, 156) - 0.8).abs() < 0.000001,
    content="true",
  )
}

///|
test "sprite_uniform_bytes:粒子路径恒等轴编码" {
  let identity = @math3d.Matrix4::identity()
  let ub = sprite_uniform_bytes(
    identity,
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_x(),
    @math3d.Vector3::unit_y(),
    @math3d.Vector3::unit_z(),
    0.0,
    @math3d.Color::white(),
    1.0,
  )
  debug_inspect(read_sprite_f32_at(ub, 64) == 0.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 80) == 1.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 100) == 1.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 120) == 1.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 128) == 0.0, content="true")
  debug_inspect(read_sprite_f32_at(ub, 156) == 1.0, content="true")
}

///|
test "Material 公告板标签:is_billboard 覆盖 kind 3/4,不覆盖 lit 族" {
  let s = @core.Material::sprite(@math3d.Color::white())
  let p = @core.Material::particle(@math3d.Color::white())
  let l = @core.Material::lambert(
    @math3d.Color::white(),
    @math3d.Color::black(),
  )
  debug_inspect(s.is_billboard() && p.is_billboard(), content="true")
  debug_inspect(l.is_billboard(), content="false")
  debug_inspect(s.kind == 3 && p.kind == 4, content="true")
}
