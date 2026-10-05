// A1 纹理管线数据层测试:mip 链生成 / from_rgba 包装 / 缺省采样参数。

///|
test "generate_mip_chain:2×2 → 1×1 精确平均" {
  // 2×2 RGBA:红/绿/蓝/黄四角,1×1 mip 应为四色均值
  let px : Bytes = b"\xff\x00\x00\xff" + b"\x00\xff\x00\xff" + b"\x00\x00\xff\xff" + b"\xff\xff\x00\xff"
  let mips = generate_mip_chain(2, 2, px)
  debug_inspect(mips.length(), content="2")
  debug_inspect(mips[0].length(), content="16")
  debug_inspect(mips[1].length(), content="4")
  // R=(红255+黄255)/4=128、G=(绿255+黄255)/4=128、B=蓝255/4→64、A=255
  debug_inspect((mips[1][0].to_int() & 0xFF), content="128")
  debug_inspect((mips[1][1].to_int() & 0xFF), content="128")
  debug_inspect((mips[1][2].to_int() & 0xFF), content="64")
  debug_inspect((mips[1][3].to_int() & 0xFF), content="255")
}

///|
test "generate_mip_chain:非二次幂 3×3 → 2×2 → 1×1" {
  let px = Bytes::makei(3 * 3 * 4, _ => b'\x80')
  let mips = generate_mip_chain(3, 3, px)
  debug_inspect(mips.length(), content="3")
  debug_inspect(mips[1].length(), content="16") // 2×2×4
  debug_inspect(mips[2].length(), content="4") // 1×1×4
}

///|
test "generate_mip_chain:1×1 单层" {
  let mips = generate_mip_chain(1, 1, b"\x10\x20\x30\xff")
  debug_inspect(mips.length(), content="1")
}

///|
test "Texture::from_rgba:带 mip 源与唯一 id" {
  let a = Texture::from_rgba(2, 2, Bytes::makei(16, _ => b'\xff'))
  let b = Texture::from_rgba(2, 2, Bytes::makei(16, _ => b'\xff'))
  debug_inspect(a.source is Some(_), content="true")
  debug_inspect(b.source is Some(_), content="true")
  debug_inspect((a.id != b.id), content="true")
  debug_inspect(a.anisotropy, content="1")
  debug_inspect(a.wrap_s is ClampToEdge, content="true")
}

///|
test "Texture::set_rgba 重建 mip 链" {
  let t = Texture::new()
  debug_inspect(t.source is None, content="true")
  t.set_rgba(2, 2, Bytes::makei(16, _ => b'\x40'))
  match t.source {
    Some(s) => debug_inspect(s.mips.length(), content="2")
    None => debug_inspect("no-source", content="has-source")
  }
}
