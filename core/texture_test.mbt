// core 包黑盒测试:Texture 数据层(对齐 three.js Texture 默认值与常数表)。

///|
test "Texture 默认值对齐 three.js 构造器" {
  let t = @core.Texture::new()
  debug_inspect(t.wrap_s.to_int(), content="1001")
  debug_inspect(t.wrap_t.to_int(), content="1001")
  debug_inspect(t.mag_filter.to_int(), content="1006")
  debug_inspect(t.min_filter.to_int(), content="1008")
  debug_inspect(t.repeat.x, content="1")
  debug_inspect(t.repeat.y, content="1")
  debug_inspect(t.offset.x, content="0")
  debug_inspect(t.offset.y, content="0")
  debug_inspect(t.color_space.to_string() == "", content="true")
}

///|
test "Wrapping 常数表:Repeat=1000、ClampToEdge=1001、MirroredRepeat=1002" {
  debug_inspect(@core.Wrapping::Repeat.to_int(), content="1000")
  debug_inspect(@core.Wrapping::ClampToEdge.to_int(), content="1001")
  debug_inspect(@core.Wrapping::MirroredRepeat.to_int(), content="1002")
}

///|
test "TextureFilter 常数表:Nearest=1003 … LinearMipmapLinear=1008" {
  debug_inspect(@core.TextureFilter::Nearest.to_int(), content="1003")
  debug_inspect(
    @core.TextureFilter::NearestMipmapNearest.to_int(),
    content="1004",
  )
  debug_inspect(
    @core.TextureFilter::NearestMipmapLinear.to_int(),
    content="1005",
  )
  debug_inspect(@core.TextureFilter::Linear.to_int(), content="1006")
  debug_inspect(
    @core.TextureFilter::LinearMipmapNearest.to_int(),
    content="1007",
  )
  debug_inspect(
    @core.TextureFilter::LinearMipmapLinear.to_int(),
    content="1008",
  )
}

///|
test "ColorSpace 字符串常数对齐 three.js" {
  debug_inspect(@core.ColorSpace::No.to_string() == "", content="true")
  debug_inspect(
    @core.ColorSpace::SRGB.to_string() == "srgb",
    content="true",
  )
  debug_inspect(
    @core.ColorSpace::LinearSRGB.to_string() == "srgb-linear",
    content="true",
  )
}

///|
test "Texture 字段可写:采样参数与 UV 平铺/偏移" {
  let t = @core.Texture::new()
  t.wrap_s = @core.Wrapping::Repeat
  t.wrap_t = @core.Wrapping::MirroredRepeat
  t.mag_filter = @core.TextureFilter::Nearest
  t.min_filter = @core.TextureFilter::NearestMipmapLinear
  t.repeat = @math3d.Vector2::new(2.0, 3.0)
  t.offset = @math3d.Vector2::new(0.25, 0.5)
  t.color_space = @core.ColorSpace::SRGB
  debug_inspect(t.wrap_s.to_int(), content="1000")
  debug_inspect(t.wrap_t.to_int(), content="1002")
  debug_inspect(t.mag_filter.to_int(), content="1003")
  debug_inspect(t.min_filter.to_int(), content="1005")
  debug_inspect(t.repeat.x, content="2")
  debug_inspect(t.repeat.y, content="3")
  debug_inspect(t.offset.x, content="0.25")
  debug_inspect(t.offset.y, content="0.5")
  debug_inspect(t.color_space.to_string() == "srgb", content="true")
}
