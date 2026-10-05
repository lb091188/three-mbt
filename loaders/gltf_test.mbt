// GLB 加载器单测:手工构造最小合法 GLB(单三角 + extras + 顶点色),
// 校验容器拆包/accessor 解码/节点树/材质映射全链路。

///| 浮点转 f32 小端 4 字节
fn f32b(v : Double) -> Bytes {
  let bits = Float::from_double(v).reinterpret_as_uint()
  Bytes::makei(
    4,
    i => ((bits >> (i * 8)) & 0xFFU).to_byte(),
  )
}

///| u32 小端
fn u32b(v : UInt) -> Bytes {
  Bytes::makei(4, i => ((v >> (i * 8)) & 0xFFU).to_byte())
}

///| u16 小端
fn u16b(v : UInt) -> Bytes {
  Bytes::makei(2, i => ((v >> (i * 8)) & 0xFFU).to_byte())
}

///| 拼接字节串
fn cat(parts : Array[Bytes]) -> Bytes {
  let n = parts.fold(init=0, fn(a, p) { a + p.length() })
  let out : FixedArray[Byte] = FixedArray::make(n, b'\x00')
  let mut off = 0
  for p in parts {
    for i in 0..<p.length() {
      out.set(off + i, p[i])
    }
    off += p.length()
  }
  Bytes::from_array(out[:])
}

test "load_glb:最小三角全链路" {
  // BIN:positions(3×VEC3) + normals(3×VEC3) + colors(3×VEC3) + indices(3×u16)
  let bin = cat([
      f32b(0.0) + f32b(0.0) + f32b(0.0) + f32b(1.0) + f32b(0.0) +
      f32b(0.0) +
      f32b(0.5) + f32b(1.0) + f32b(0.0), // positions
      f32b(0.0) + f32b(0.0) + f32b(1.0) + f32b(0.0) + f32b(0.0) +
      f32b(1.0) +
      f32b(0.0) + f32b(0.0) + f32b(1.0), // normals
      f32b(1.0) + f32b(0.0) + f32b(0.0) + f32b(0.0) + f32b(1.0) +
      f32b(0.0) +
      f32b(0.0) + f32b(0.0) + f32b(1.0), // colors
      u16b(0U) + u16b(1U) + u16b(2U), // indices
    ])
  let json_str = "{\"scene\":0,\"scenes\":[{\"nodes\":[0]}],\"nodes\":[{\"name\":\"tri\",\"mesh\":0,\"translation\":[1.0,2.0,3.0],\"extras\":{\"zone\":\"hull\",\"armor\":30,\"wheelR\":0.4}}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0,\"NORMAL\":1,\"COLOR_0\":2},\"indices\":3,\"material\":0}]}],\"materials\":[{\"pbrMetallicRoughness\":{\"baseColorFactor\":[0.2,0.4,0.6,1.0]}}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":2,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":3,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"bufferViews\":[{\"byteOffset\":0,\"byteLength\":36},{\"byteOffset\":36,\"byteLength\":36},{\"byteOffset\":72,\"byteLength\":36},{\"byteOffset\":108,\"byteLength\":6}],\"buffers\":[{\"byteLength\":114}]}"
  // JSON 块空格补齐到 4 字节倍数
  let json_bytes_raw = @utf8.encode(json_str)
  let pad = (4 - json_bytes_raw.length() % 4) % 4
  let json_bytes = cat([json_bytes_raw, Bytes::makei(pad, _ => b' ')])
  let bin_pad = (4 - bin.length() % 4) % 4
  let bin_padded = cat([bin, Bytes::makei(bin_pad, _ => b'\x00')])
  let total = 12 + 8 + json_bytes.length() + 8 + bin_padded.length()
  let glb = cat([
      u32b(0x46546C67U) + u32b(2U) + u32b(total.reinterpret_as_uint()),
      u32b(json_bytes.length().reinterpret_as_uint()) + u32b(0x4E4F534AU),
      json_bytes,
      u32b(bin_padded.length().reinterpret_as_uint()) + u32b(0x004E4942U),
      bin_padded,
    ])
  let root = load_glb(glb)
  let tri = find_node_by_name(root, "tri")
  debug_inspect(tri is Some(_), content="true")
  let n = tri.unwrap()
  // TRS translation
  debug_inspect(n.position.x, content="1")
  debug_inspect(n.position.y, content="2")
  debug_inspect(n.position.z, content="3")
  // extras(字符串化)
  debug_inspect(n.extras.get("zone"), content="Some(\"hull\")")  // Map[] 返回 V?
  debug_inspect(n.extras.get("armor"), content="Some(\"30\")")
  debug_inspect(n.extras.get("wheelR"), content="Some(\"0.4\")")
  // 几何
  let m = n.mesh.unwrap()
  debug_inspect(m.geometry.positions.length(), content="9")
  debug_inspect(m.geometry.positions[3], content="1")
  debug_inspect(m.geometry.positions[5], content="0")
  debug_inspect(m.geometry.colors.length(), content="9")
  debug_inspect(m.geometry.colors[0], content="1")
  debug_inspect(m.geometry.indices.length(), content="3")
  debug_inspect(m.geometry.indices[2], content="2")
  // 材质:baseColorFactor + 顶点色开关
  debug_inspect(m.material.color.r, content="0.2")
  debug_inspect(m.material.color.g, content="0.4")
  debug_inspect(m.material.vertex_colors, content="true")
}

test "load_glb:坏 magic 报错" {
  let bad = Bytes::makei(32, _ => b'\x00')
  try {
    let _ = load_glb(bad)
    fail("预期报错但成功")
  } catch {
    _ => ()
  }
}

///| 用指定 materials[0] JSON 构造最小三角 GLB(positions/normals/indices)
///| 并加载,返回其材质 —— A3 PBR→Phong 降级三例共用
fn load_mat_from_glb(mat_json : String) -> @core.Material raise Error {
  let bin = cat([
      f32b(0.0) + f32b(0.0) + f32b(0.0) + f32b(1.0) + f32b(0.0) +
      f32b(0.0) +
      f32b(0.5) + f32b(1.0) + f32b(0.0), // positions
      f32b(0.0) + f32b(0.0) + f32b(1.0) + f32b(0.0) + f32b(0.0) +
      f32b(1.0) +
      f32b(0.0) + f32b(0.0) + f32b(1.0), // normals
      u16b(0U) + u16b(1U) + u16b(2U), // indices
    ])
  let json_str = "{\"scene\":0,\"scenes\":[{\"nodes\":[0]}],\"nodes\":[{\"name\":\"tri\",\"mesh\":0}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0,\"NORMAL\":1},\"indices\":2,\"material\":0}]}],\"materials\":[" + mat_json + "],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":2,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"bufferViews\":[{\"byteOffset\":0,\"byteLength\":36},{\"byteOffset\":36,\"byteLength\":36},{\"byteOffset\":72,\"byteLength\":6}],\"buffers\":[{\"byteLength\":78}]}"
  let json_bytes_raw = @utf8.encode(json_str)
  let pad = (4 - json_bytes_raw.length() % 4) % 4
  let json_bytes = cat([json_bytes_raw, Bytes::makei(pad, _ => b' ')])
  let bin_pad = (4 - bin.length() % 4) % 4
  let bin_padded = cat([bin, Bytes::makei(bin_pad, _ => b'\x00')])
  let total = 12 + 8 + json_bytes.length() + 8 + bin_padded.length()
  let glb = cat([
      u32b(0x46546C67U) + u32b(2U) + u32b(total.reinterpret_as_uint()),
      u32b(json_bytes.length().reinterpret_as_uint()) + u32b(0x4E4F534AU),
      json_bytes,
      u32b(bin_padded.length().reinterpret_as_uint()) + u32b(0x004E4942U),
      bin_padded,
    ])
  let root = load_glb(glb)
  let n = find_node_by_name(root, "tri").unwrap()
  n.mesh.unwrap().material
}

test "load_glb:pbr(metallic=0.9,roughness=0.2) 降级 Phong" {
  let m = load_mat_from_glb(
      "{\"pbrMetallicRoughness\":{\"baseColorFactor\":[0.25,0.5,0.75,1.0],\"metallicFactor\":0.9,\"roughnessFactor\":0.2},\"emissiveFactor\":[0.1,0.2,0.3]}",
    )
  debug_inspect(m.is_phong(), content="true")
  // 高光灰度 s = clamp(0.04+0.96*metallic) ≈ 0.904,三通道同值
  let s_expected = 0.04 + 0.96 * 0.9
  debug_inspect((m.specular.r - s_expected).abs() < 0.000000000001, content="true")
  debug_inspect((m.specular.g - s_expected).abs() < 0.000000000001, content="true")
  debug_inspect((m.specular.b - s_expected).abs() < 0.000000000001, content="true")
  debug_inspect((m.specular.r - 0.904).abs() < 0.000000001, content="true")
  // shininess = clamp((1-0.2)^2*250+5) ≈ 165
  let shin_expected = (1.0 - 0.2) * (1.0 - 0.2) * 250.0 + 5.0
  debug_inspect((m.shininess - shin_expected).abs() < 0.000000000001, content="true")
  debug_inspect((m.shininess - 165.0).abs() < 0.000000001, content="true")
  // baseColorFactor / emissiveFactor 透传
  debug_inspect((m.color.r - 0.25).abs() < 0.000000001, content="true")
  debug_inspect((m.color.b - 0.75).abs() < 0.000000001, content="true")
  debug_inspect((m.emissive.r - 0.1).abs() < 0.000000001, content="true")
  debug_inspect((m.emissive.g - 0.2).abs() < 0.000000001, content="true")
}

test "load_glb:无 pbr 块维持 Lambert" {
  let m = load_mat_from_glb("{\"name\":\"plain\"}")
  debug_inspect(m.is_lambert(), content="true")
  debug_inspect(m.specular.r == 0.0, content="true")
  debug_inspect(m.specular.g == 0.0, content="true")
  debug_inspect(m.emissive.b == 0.0, content="true")
  // 无 baseColorFactor 默认白
  debug_inspect(m.color.r == 1.0, content="true")
}

test "load_glb:pbr(metallic=0.0,roughness=1.0) 粗糙维持 Lambert" {
  let m = load_mat_from_glb(
      "{\"pbrMetallicRoughness\":{\"metallicFactor\":0.0,\"roughnessFactor\":1.0,\"baseColorFactor\":[0.3,0.3,0.3,1.0]}}",
    )
  debug_inspect(m.is_lambert(), content="true")
  debug_inspect(m.specular.r == 0.0, content="true")
  debug_inspect((m.color.g - 0.3).abs() < 0.000000001, content="true")
  // Lambert 默认 shininess=30(构造器默认,非 PBR 换算)
  debug_inspect(m.shininess == 30.0, content="true")
}

test "load_glb:pbr 默认参数(缺 metallic/roughness 因子)也维持 Lambert" {
  // 129 个坦克 GLB 的典型形态:pbr 块只有 baseColorFactor,
  // 缺省 metallic=1.0/roughness=1.0(glTF 规范默认)→ 不升 Phong
  let m = load_mat_from_glb(
      "{\"pbrMetallicRoughness\":{\"baseColorFactor\":[0.2,0.4,0.6,1.0]}}",
    )
  debug_inspect(m.is_lambert(), content="true")
  debug_inspect(m.specular.r == 0.0, content="true")
}
