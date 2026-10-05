// GLB/glTF 2.0 加载器:覆盖游戏 129 个坦克模型的全部特性面
// (2026-10-05 全量扫描收敛):
//   - 容器:JSON chunk + BIN chunk,无外部 .bin/uri
//   - accessor 仅三组合:float32×VEC3(位置/法线/颜色)、uint16×SCALAR(索引)、
//     float32×VEC2(7 个带贴图模型的 TEXCOORD_0)
//   - 节点 TRS(实测仅 translation)+ extras(type/wheelR/zone/armor)
//   - 7 个模型带内嵌贴图(bufferView + mimeType)+ baseColorTexture
//   - 颜色主力是 COLOR_0 顶点色(迷彩),材质 baseColorFactor 多为白
// metallic/roughness → Phong 降级(A3 已落,策略见 build_material 头注释);
// emissiveFactor → 材质自发光。
// 骨骼/动画/蒙皮/多 primitive 超集按需报错或退化(单 primitive 直接挂节点,
// 多 primitive 退化为子 mesh)。

///| GLB 容器拆包结果(BIN 块以 raw 内绝对偏移记录,免 view 拷贝)
struct GlbContainer {
  json : Json
  raw : Bytes
  bin_abs : Int
  bin_len : Int
}

///| 小端读 u32
fn le32(b : Bytes, off : Int) -> Int {
  (b[off].to_int() & 0xFF) | ((b[off + 1].to_int() & 0xFF) << 8) |
  ((b[off + 2].to_int() & 0xFF) << 16) | ((b[off + 3].to_int() & 0xFF) << 24)
}

///| 拆 GLB 容器:校验 magic/version,收集 JSON 与 BIN 块
fn parse_glb_container(raw : Bytes) -> GlbContainer raise Error {
  if raw.length() < 20 {
    raise Failure("GLB 过短")
  }
  if le32(raw, 0) != 0x46546C67 { // "glTF"
    raise Failure("不是 GLB(magic 不符)")
  }
  let ver = le32(raw, 4)
  if ver != 2 {
    raise Failure("仅支持 glTF 2.0,实际 \{ver}")
  }
  let mut json : Json? = None
  let mut bin_abs = -1
  let mut bin_len = 0
  let mut off = 12
  while off + 8 <= raw.length() {
    let clen = le32(raw, off)
    let ctype = le32(raw, off + 4)
    let data = raw[off + 8:off + 8 + clen]
    if clen < 0 || off + 8 + clen > raw.length() {
      raise Failure("GLB 块越界")
    }
    if ctype == 0x4E4F534A { // "JSON"
      let s = @utf8.decode(data) catch {
        _ => raise Failure("JSON 块非 UTF-8")
      }
      json = Some(
        @json.parse(s) catch {
          e => raise Failure("glTF JSON 解析失败: \{e}")
        },
      )
    } else if ctype == 0x004E4942 { // "BIN\0"
      bin_abs = off + 8
      bin_len = clen
    }
    off += 8 + clen
  }
  match json {
    Some(j) => { json: j, raw, bin_abs, bin_len }
    None => raise Failure("GLB 无 JSON 块")
  }
}

///| 取子键(object);缺失返回 None
fn jv(j : Json, key : String) -> Json? {
  j.value(key)
}

///| 取数字子键(缺失/非数返回默认)
fn jf(j : Json, key : String, default : Double) -> Double {
  match jv(j, key) {
    Some(v) => v.as_number().unwrap_or(default)
    None => default
  }
}

///| 取整数子键
fn ji(j : Json, key : String) -> Int? {
  match jv(j, key) {
    Some(v) => v.as_number().map(fn(n) { n.to_int() })
    None => None
  }
}

///| accessor 读取上下文(json + 原始字节 + BIN 绝对偏移)
struct AccCtx {
  json : Json
  raw : Bytes
  bin_abs : Int
}

///| BIN 块内取字节(BIN 相对偏移)
fn bin_at(ctx : AccCtx, i : Int) -> Byte {
  ctx.raw[ctx.bin_abs + i]
}

///| 读 accessor 为 f64 数组(VEC2/VEC3;componentType=5126 float32)
fn accessor_f32_array(
  ctx : AccCtx,
  acc_idx : Int,
  comps : Int,
) -> Array[Double] raise Error {
  let accs = ctx.json.value("accessors").unwrap()
  let acc = accs.item(acc_idx).unwrap()
  let count = ji(acc, "count").unwrap()
  let byte_offset = ji(acc, "byteOffset").unwrap_or(0)
  let ct = ji(acc, "componentType").unwrap()
  if ct != 5126 {
    raise Failure("accessor#\{acc_idx} 非 float32(componentType=\{ct})")
  }
  let bvs = ctx.json.value("bufferViews").unwrap()
  let bv_idx = ji(acc, "bufferView").unwrap()
  let bv = bvs.item(bv_idx).unwrap()
  let bv_off = ji(bv, "byteOffset").unwrap_or(0)
  let stride = ji(bv, "byteStride").unwrap_or(comps * 4)
  let out : Array[Double] = []
  let base = bv_off + byte_offset
  for i in 0..<count {
    for c in 0..<comps {
      let off = base + i * stride + c * 4
      let bits = (bin_at(ctx, off).to_uint() & 0xFFU) |
        ((bin_at(ctx, off + 1).to_uint() & 0xFFU) << 8) |
        ((bin_at(ctx, off + 2).to_uint() & 0xFFU) << 16) |
        ((bin_at(ctx, off + 3).to_uint() & 0xFFU) << 24)
      out.push(Float::reinterpret_from_uint(bits).to_double())
    }
  }
  out
}

///| 读 SCALAR 索引 accessor 为 u32 数组(5123=uint16 / 5125=uint32)
fn accessor_index_array(
  ctx : AccCtx,
  acc_idx : Int,
) -> Array[UInt] raise Error {
  let accs = ctx.json.value("accessors").unwrap()
  let acc = accs.item(acc_idx).unwrap()
  let count = ji(acc, "count").unwrap()
  let byte_offset = ji(acc, "byteOffset").unwrap_or(0)
  let ct = ji(acc, "componentType").unwrap()
  let bvs = ctx.json.value("bufferViews").unwrap()
  let bv = bvs.item(ji(acc, "bufferView").unwrap()).unwrap()
  let bv_off = ji(bv, "byteOffset").unwrap_or(0)
  let stride = ji(bv, "byteStride").unwrap_or(if ct == 5123 { 2 } else { 4 })
  let out : Array[UInt] = []
  let base = bv_off + byte_offset
  for i in 0..<count {
    let off = base + i * stride
    let v : UInt = if ct == 5123 {
      (bin_at(ctx, off).to_uint() & 0xFFU) |
      ((bin_at(ctx, off + 1).to_uint() & 0xFFU) << 8)
    } else if ct == 5125 {
      (bin_at(ctx, off).to_uint() & 0xFFU) |
      ((bin_at(ctx, off + 1).to_uint() & 0xFFU) << 8) |
      ((bin_at(ctx, off + 2).to_uint() & 0xFFU) << 16) |
      ((bin_at(ctx, off + 3).to_uint() & 0xFFU) << 24)
    } else {
      raise Failure("索引 accessor#\{acc_idx} 非 u16/u32(ct=\{ct})")
    }
    out.push(v)
  }
  out
}

///| 内嵌图像 → 纹理(images[i].bufferView + mimeType)
fn load_embedded_texture(
  ctx : AccCtx,
  image_idx : Int,
) -> @core.Texture raise Error {
  let img = ctx.json.value("images").unwrap().item(image_idx).unwrap()
  let bv_idx = ji(img, "bufferView").unwrap()
  let bv = ctx.json.value("bufferViews").unwrap().item(bv_idx).unwrap()
  let off = ji(bv, "byteOffset").unwrap_or(0)
  let len = ji(bv, "byteLength").unwrap()
  let data = Bytes::makei(len, i => bin_at(ctx, off + i))
  let mime = match jv(img, "mimeType") {
    Some(m) => m.as_string().unwrap_or("image/png")
    None => "image/png"
  }
  let t = (if mime == "image/jpeg" {
      load_texture_jpeg_bytes(data)
    } else {
      load_texture_png_bytes(data)
    }) catch {
    e => raise Failure("内嵌贴图解码失败(\{mime}): \{e}")
  }
  // glTF 默认 wrap=REPEAT(10497)
  t.wrap_s = @core.Wrapping::Repeat
  t.wrap_t = @core.Wrapping::Repeat
  t
}

///| Double 区间夹取(核心库 Int::clamp 有 Double 版无,自备)
fn clampd(v : Double, lo : Double, hi : Double) -> Double {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///| glTF 材质 → three-native 材质:Lambert(基础色 × 顶点色 × 贴图)+
///| PBR→Phong 降级。
///|
///| 降级策略(A3,写给后来人):
///| - glTF 2.0 默认 metallicFactor=1.0、roughnessFactor=1.0(字段缺省即此值),
///|   本仓 129 个坦克 GLB 绝大多数不写或写默认值,等效全粗糙无高光。
///| - 仅当材质带 pbrMetallicRoughness 块 且 roughnessFactor < 0.9 才升 Phong
///|   (足够光滑才有可见高光);其余(含无 pbr 块、粗糙度 ≥ 0.9)维持 Lambert
///|   ——避免默认参数模型整体变高光、观感漂移。
///| - Phong 近似(金属度/粗糙度 → Blinn-Phong 两参数):
///|     高光灰度 s = clamp(0.04 + 0.96 * metallic, 0, 1)(电介质 F0=0.04 起,
///|     金属度拉满到 1),specular 取 (s, s, s);
///|     shininess = clamp((1 - roughness)^2 * 250 + 5, 5, 250)(越光滑越锐)。
///| - emissiveFactor(材质顶层,默认 [0,0,0])写进 emissive;
///|   Lambert/Phong 管线 uniform 224 偏移已有写入通道,无需改渲染层。
fn build_material(
  ctx : AccCtx,
  mat_idx : Int,
  has_vertex_colors : Bool,
) -> @core.Material raise Error {
  let mat = ctx.json.value("materials").unwrap().item(mat_idx).unwrap()
  let pbr = jv(mat, "pbrMetallicRoughness")
  let (r, g, b) = match pbr {
    Some(p) =>
      match jv(p, "baseColorFactor") {
        Some(f) => {
          let a = f.as_array().unwrap_or([])
          if a.length() >= 3 {
            (
              a[0].as_number().unwrap_or(1.0),
              a[1].as_number().unwrap_or(1.0),
              a[2].as_number().unwrap_or(1.0),
            )
          } else {
            (1.0, 1.0, 1.0)
          }
        }
        None => (1.0, 1.0, 1.0)
      }
    None => (1.0, 1.0, 1.0)
  }
  // emissiveFactor → 自发光色(材质顶层字段,glTF 默认黑)
  let (er, eg, eb) = match jv(mat, "emissiveFactor") {
    Some(f) => {
      let a = f.as_array().unwrap_or([])
      if a.length() >= 3 {
        (
          a[0].as_number().unwrap_or(0.0),
          a[1].as_number().unwrap_or(0.0),
          a[2].as_number().unwrap_or(0.0),
        )
      } else {
        (0.0, 0.0, 0.0)
      }
    }
    None => (0.0, 0.0, 0.0)
  }
  let emissive = @math3d.Color::new(er, eg, eb)
  let color = @math3d.Color::new(r, g, b)
  // PBR→Phong 降级判定与参数换算(策略见函数头注释)
  let m = match pbr {
    Some(p) => {
      let metallic = jf(p, "metallicFactor", 1.0)
      let roughness = jf(p, "roughnessFactor", 1.0)
      if roughness < 0.9 {
        let s = clampd(0.04 + 0.96 * metallic, 0.0, 1.0)
        let shininess = clampd(
          (1.0 - roughness) * (1.0 - roughness) * 250.0 + 5.0,
          5.0,
          250.0,
        )
        @core.Material::phong(
          color,
          @math3d.Color::new(s, s, s),
          shininess,
          emissive,
        )
      } else {
        @core.Material::lambert(color, emissive)
      }
    }
    None => @core.Material::lambert(color, emissive)
  }
  m.vertex_colors = has_vertex_colors
  // baseColorTexture:{index} → textures[i].source → images[j]
  match pbr {
    Some(p) =>
      match jv(p, "baseColorTexture") {
        Some(bt) =>
          match ji(bt, "index") {
            Some(tex_idx) => {
              let tex = ctx.json.value("textures").unwrap().item(tex_idx).unwrap()
              let src = ji(tex, "source").unwrap()
              m.map = Some(load_embedded_texture(ctx, src))
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  m
}

///| mesh → 几何(POSITION/NORMAL/COLOR_0/TEXCOORD_0 + 索引)
fn build_geometry(
  ctx : AccCtx,
  mesh_idx : Int,
) -> ((@core.BufferGeometry, Bool, Int?)) raise Error {
  let mesh = ctx.json.value("meshes").unwrap().item(mesh_idx).unwrap()
  let prims = mesh.value("primitives").unwrap().as_array().unwrap_or([])
  if prims.is_empty() {
    raise Failure("mesh#\{mesh_idx} 无 primitive")
  }
  // 游戏 129 模型全是单 primitive;多 primitive 取第一个并记警告
  if prims.length() > 1 {
    println("gltf: mesh#\{mesh_idx} 多 primitive,取第一个(游戏模型不应出现)")
  }
  let p = prims[0]
  let attrs = p.value("attributes").unwrap()
  let positions = accessor_f32_array(
      ctx,
      ji(attrs, "POSITION").unwrap(),
      3,
    )
  let normals = match ji(attrs, "NORMAL") {
    Some(i) => accessor_f32_array(ctx, i, 3)
    None => []
  }
  let uvs = match ji(attrs, "TEXCOORD_0") {
    Some(i) => accessor_f32_array(ctx, i, 2)
    None => []
  }
  let colors = match ji(attrs, "COLOR_0") {
    Some(i) => accessor_f32_array(ctx, i, 3)
    None => []
  }
  let indices = match ji(p, "indices") {
    Some(i) => accessor_index_array(ctx, i)
    None => []
  }
  let mat_idx = ji(p, "material")
  let geo : @core.BufferGeometry = {
    positions,
    normals,
    uvs,
    colors,
    indices,
  }
  (geo, colors.length() > 0, mat_idx)
}

///| 递归建节点树:TRS/extras/mesh/children
fn build_node(
  ctx : AccCtx,
  node_idx : Int,
) -> @core.Object3D raise Error {
  let node = ctx.json.value("nodes").unwrap().item(node_idx).unwrap()
  let o = @core.Object3D::new()
  o.name = match jv(node, "name") {
    Some(n) => n.as_string().unwrap_or("")
    None => ""
  }
  match jv(node, "translation") {
    Some(t) => {
      let a = t.as_array().unwrap_or([])
      if a.length() >= 3 {
        o.position = @math3d.Vector3::new(
          a[0].as_number().unwrap_or(0.0),
          a[1].as_number().unwrap_or(0.0),
          a[2].as_number().unwrap_or(0.0),
        )
      }
    }
    None => ()
  }
  match jv(node, "rotation") {
    Some(r) => {
      let a = r.as_array().unwrap_or([])
      if a.length() >= 4 {
        // glTF 四元数存 xyzw;three-native Quaternion 字段序确认:x y z w
        // glTF 四元数 xyzw;three-native Quaternion 字段同序
        o.rotation = {
          x: a[0].as_number().unwrap_or(0.0),
          y: a[1].as_number().unwrap_or(0.0),
          z: a[2].as_number().unwrap_or(0.0),
          w: a[3].as_number().unwrap_or(1.0),
        }
      }
    }
    None => ()
  }
  match jv(node, "scale") {
    Some(t) => {
      let a = t.as_array().unwrap_or([])
      if a.length() >= 3 {
        o.scale = @math3d.Vector3::new(
          a[0].as_number().unwrap_or(1.0),
          a[1].as_number().unwrap_or(1.0),
          a[2].as_number().unwrap_or(1.0),
        )
      }
    }
    None => ()
  }
  // extras:值字符串化(数字保 JSON 原始 repr 由调用方 parse)
  match jv(node, "extras") {
    Some(e) =>
      match e.as_object() {
        Some(m) => for kv in m {
            let val : String = match kv.1 {
              Number(n, ..) => n.to_string()
              String(s) => s
              True => "true"
              False => "false"
              Null => "null"
              _ => "<complex>"
            }
            o.extras[kv.0] = val
          }
        None => ()
      }
    None => ()
  }
  // mesh
  match ji(node, "mesh") {
    Some(mi) => {
      let (geo, has_vc, mat_idx) = build_geometry(ctx, mi)
      let mat = match mat_idx {
        Some(m) => build_material(ctx, m, has_vc)
        None => {
          let m = @core.Material::lambert(
            @math3d.Color::white(),
            @math3d.Color::black(),
          )
          m.vertex_colors = has_vc
          m
        }
      }
      o.mesh = Some({ geometry: geo, material: mat })
    }
    None => ()
  }
  // children
  match jv(node, "children") {
    Some(cs) =>
      match cs.as_array() {
        Some(arr) => for c in arr {
            let ci = c.as_number().unwrap().to_int()
            let child = build_node(ctx, ci)
            o.add(child)
          }
        None => ()
      }
    None => ()
  }
  o
}

///| 加载 GLB 字节 → 默认场景根节点(节点树 + 网格 + 材质/贴图 + extras)
pub fn load_glb(raw : Bytes) -> @core.Object3D raise Error {
  let c = parse_glb_container(raw)
  if c.bin_abs < 0 {
    raise Failure("GLB 无 BIN 块(游戏模型应内嵌)")
  }
  let ctx : AccCtx = { json: c.json, raw: c.raw, bin_abs: c.bin_abs }
  let scene_idx = ji(c.json, "scene").unwrap_or(0)
  let scenes = c.json.value("scenes").unwrap()
  let scene = scenes.item(scene_idx).unwrap()
  let roots = scene.value("nodes").unwrap().as_array().unwrap_or([])
  let root = @core.Object3D::new()
  root.name = "glb_root"
  for r in roots {
    let ri = r.as_number().unwrap().to_int()
    root.add(build_node(ctx, ri))
  }
  root.update_matrix_world(true)
  root
}

///| 按名查找节点(先序遍历;装配用:turret/gun/muzzle)
pub fn find_node_by_name(
  root : @core.Object3D,
  name : String,
) -> @core.Object3D? {
  let found : Ref[@core.Object3D?] = Ref(None)
  root.traverse(fn(o) {
    if found.val is None && o.name == name {
      found.val = Some(o)
    }
    true
  })
  found.val
}
