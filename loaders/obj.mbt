// OBJ 加载器:对照 three.js OBJLoader(examples/jsm/loaders/OBJLoader.js)
// 的几何解析语义——v/vt/vn 属性表 + f 面(v、v/vt、v//vn、v/vt/vn 四种
// 顶点格式),任意多边形扇形三角化;不含材质(o/g/s/usemtl/mtllib 认识
// 但不产生几何),不含 l 线/p 点。解析容错:坏行(数字非法、索引越界、
// 无法识别的指令)整行跳过,由 parse_obj_detailed 返回跳过计数。

///|
/// OBJ 解析结果:合并几何 + 容错统计
pub(all) struct ObjParseResult {
  /// 解析出的几何(多个 o/g 分组的面合并进同一几何)
  geometry : @core.BufferGeometry
  /// 被跳过的行数:格式坏行与不支持的行(l/p 及未知指令);注释与空行不计
  skipped_lines : Int
}

///| 解析 OBJ 文本为单个 BufferGeometry(多 o/g 分组合并)。

///| 顶点索引不做去重:面顶点直接展开,indices 为顺序号 0..n-1

///|
/// (three.js OBJLoader 产出的是非索引几何,这里为配合索引绘制补顺序索引)
pub fn parse_obj(text : String) -> @core.BufferGeometry {
  parse_obj_detailed(text).geometry
}

///|
/// 解析 OBJ 文本,带回容错统计(跳过的坏行数)
pub fn parse_obj_detailed(text : String) -> ObjParseResult {
  // 预处理:CRLF 归一、反斜杠续行拼接(对照 OBJLoader.parse 的两次 replace)
  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\\\n", new="")
  // 源属性表(v/vt/vn,各分量连续存储)
  let src_positions : Array[Double] = []
  let src_normals : Array[Double] = []
  let src_uvs : Array[Double] = []
  // 输出几何(每面顶点直接展开)
  let out_positions : Array[Double] = []
  let out_normals : Array[Double] = []
  let out_uvs : Array[Double] = []
  let out_indices : Array[UInt] = []
  let has_uv_indices = Ref(false)
  let skipped = Ref(0)
  for line in normalized.split("\n") {
    let tokens = obj_tokens(line)
    if tokens.length() == 0 {
      continue
    }
    let head = tokens[0]
    // 行首 '#'(trimStart 后首字符,对照 OBJLoader 的注释跳过)
    if head.char_length() > 0 && head.unsafe_get(0).to_int() == 35 {
      continue
    }
    if head.equal_to_string("v") {
      // 顶点 x y z(第 7 列起的顶点色不支持,忽略)
      if tokens.length() >= 4 {
        match
          (
            parse_double_token(tokens[1]),
            parse_double_token(tokens[2]),
            parse_double_token(tokens[3]),
          ) {
          (Some(x), Some(y), Some(z)) => {
            src_positions.push(x)
            src_positions.push(y)
            src_positions.push(z)
          }
          _ => skipped.val = skipped.val + 1
        }
      } else {
        skipped.val = skipped.val + 1
      }
    } else if head.equal_to_string("vn") {
      if tokens.length() >= 4 {
        match
          (
            parse_double_token(tokens[1]),
            parse_double_token(tokens[2]),
            parse_double_token(tokens[3]),
          ) {
          (Some(x), Some(y), Some(z)) => {
            src_normals.push(x)
            src_normals.push(y)
            src_normals.push(z)
          }
          _ => skipped.val = skipped.val + 1
        }
      } else {
        skipped.val = skipped.val + 1
      }
    } else if head.equal_to_string("vt") {
      // 纹理坐标 u v(第三列 w 忽略,对照 OBJLoader 只取两列)
      if tokens.length() >= 3 {
        match (parse_double_token(tokens[1]), parse_double_token(tokens[2])) {
          (Some(u), Some(v)) => {
            src_uvs.push(u)
            src_uvs.push(v)
          }
          _ => skipped.val = skipped.val + 1
        }
      } else {
        skipped.val = skipped.val + 1
      }
    } else if head.equal_to_string("f") {
      if !obj_face_row(
          tokens, src_positions, src_normals, src_uvs, out_positions, out_normals,
          out_uvs, out_indices, has_uv_indices,
        ) {
        skipped.val = skipped.val + 1
      }
    } else if head.equal_to_string("o") ||
      head.equal_to_string("g") ||
      head.equal_to_string("s") ||
      head.equal_to_string("usemtl") ||
      head.equal_to_string("mtllib") ||
      head.equal_to_string("usemap") {
      // 分组/平滑/材质指令:认识但不产生几何(本加载器不含材质)
      ()
    } else {
      // l 线、p 点与未知指令:不支持,计为跳过行
      skipped.val = skipped.val + 1
    }
  }
  let geometry : @core.BufferGeometry = {
    positions: out_positions,
    normals: out_normals,
    // 对照 OBJLoader:只有面里实际引用过 vt 才输出 uv 属性
    uvs: if has_uv_indices.val {
      out_uvs
    } else {
      []
    },
    colors: [],
    indices: out_indices,
  }
  { geometry, skipped_lines: skipped.val, }
}

///| 处理一行 f 指令:解析全部面顶点后扇形三角化(首顶点与相邻两点

///| 组成三角形,对照 OBJLoader 的 v1/(vj,vj+1) 循环);任一顶点格式

///|
/// 非法或顶点数 <3 返回 false(整行跳过)
fn obj_face_row(
  tokens : Array[StringView],
  src_positions : Array[Double],
  src_normals : Array[Double],
  src_uvs : Array[Double],
  out_positions : Array[Double],
  out_normals : Array[Double],
  out_uvs : Array[Double],
  out_indices : Array[UInt],
  has_uv_indices : Ref[Bool],
) -> Bool {
  let vertex_count = src_positions.length() / 3
  let normal_count = src_normals.length() / 3
  let uv_count = src_uvs.length() / 2
  let face : Array[(Int, Int?, Int?)] = []
  for i in 1..<tokens.length() {
    match parse_face_token(tokens[i], vertex_count, normal_count, uv_count) {
      Some(v) => face.push(v)
      None => return false
    }
  }
  if face.length() < 3 {
    return false
  }
  for j in 1..<(face.length() - 1) {
    obj_emit_triangle(
      face[0],
      face[j],
      face[j + 1],
      src_positions,
      src_normals,
      src_uvs,
      out_positions,
      out_normals,
      out_uvs,
      out_indices,
      has_uv_indices,
    )
  }
  true
}

///| 面顶点 token(v、v/vt、v//vn、v/vt/vn)→ (顶点索引, uv 索引?, 法线索引?),

///| 索引按 OBJ 语义换算为 0 基(正数 1 基、负数从已解析末尾倒数);

///|
/// 非数字、0、越界返回 None
fn parse_face_token(
  tok : StringView,
  vertex_count : Int,
  normal_count : Int,
  uv_count : Int,
) -> (Int, Int?, Int?)? {
  let parts = tok.split("/").to_array()
  if parts.length() == 0 || parts.length() > 3 {
    return None
  }
  let vertex = match resolve_obj_index(parts[0], vertex_count) {
    Some(i) => i
    None => return None
  }
  let uv = if parts.length() >= 2 && parts[1].char_length() > 0 {
    match resolve_obj_index(parts[1], uv_count) {
      Some(i) => Some(i)
      None => return None
    }
  } else {
    None
  }
  let normal = if parts.length() >= 3 && parts[2].char_length() > 0 {
    match resolve_obj_index(parts[2], normal_count) {
      Some(i) => Some(i)
      None => return None
    }
  } else {
    None
  }
  Some((vertex, uv, normal))
}

///| OBJ 索引(1 基,负数从已解析末尾倒数)→ 0 基数组下标,

///| 对照 OBJLoader parseVertexIndex:index>0 取 index-1、index<0 取

///|
/// index+count;0 与越界返回 None
fn resolve_obj_index(text : StringView, count : Int) -> Int? {
  match parse_int_token(text) {
    None => None
    Some(idx) => {
      let resolved = if idx > 0 {
        idx - 1
      } else if idx < 0 {
        idx + count
      } else {
        return None
      }
      if resolved >= 0 && resolved < count {
        Some(resolved)
      } else {
        None
      }
    }
  }
}

///| 输出一个三角形的 3 顶点(直接展开,索引顺序追加)。

///| 法线对照 OBJLoader addFace:三顶点全带 vn 用各自 vn,否则算面法线

///| ((C-B)×(A-B) 归一,退化三角形得 (0,0,0));uv 对照 addUV/addDefaultUV:

///|
/// 顶点带 vt 用 vt、缺席补 (0,0),只有真正引用过 vt 才输出 uv 属性
fn obj_emit_triangle(
  a : (Int, Int?, Int?),
  b : (Int, Int?, Int?),
  c : (Int, Int?, Int?),
  src_positions : Array[Double],
  src_normals : Array[Double],
  src_uvs : Array[Double],
  out_positions : Array[Double],
  out_normals : Array[Double],
  out_uvs : Array[Double],
  out_indices : Array[UInt],
  has_uv_indices : Ref[Bool],
) -> Unit {
  let base = out_positions.length() / 3
  for vertex in [a.0, b.0, c.0] {
    out_positions.push(src_positions[vertex * 3])
    out_positions.push(src_positions[vertex * 3 + 1])
    out_positions.push(src_positions[vertex * 3 + 2])
  }
  match (a.2, b.2, c.2) {
    (Some(na), Some(nb), Some(nc)) =>
      for ni in [na, nb, nc] {
        out_normals.push(src_normals[ni * 3])
        out_normals.push(src_normals[ni * 3 + 1])
        out_normals.push(src_normals[ni * 3 + 2])
      }
    _ => {
      // 面法线:cb = C-B、ab = A-B,n = cb×ab(math3d normalize 对零向量
      // 回 (0,0,0),对照 three.js Vector3.normalize 的零保护)
      let va = @math3d.Vector3::new(
        src_positions[a.0 * 3],
        src_positions[a.0 * 3 + 1],
        src_positions[a.0 * 3 + 2],
      )
      let vb = @math3d.Vector3::new(
        src_positions[b.0 * 3],
        src_positions[b.0 * 3 + 1],
        src_positions[b.0 * 3 + 2],
      )
      let vc = @math3d.Vector3::new(
        src_positions[c.0 * 3],
        src_positions[c.0 * 3 + 1],
        src_positions[c.0 * 3 + 2],
      )
      let n = vc.sub(vb).cross(va.sub(vb)).normalize()
      for _ in 0..<3 {
        out_normals.push(n.x)
        out_normals.push(n.y)
        out_normals.push(n.z)
      }
    }
  }
  if a.1 is Some(_) || b.1 is Some(_) || c.1 is Some(_) {
    has_uv_indices.val = true
    for uv in [a.1, b.1, c.1] {
      match uv {
        Some(i) => {
          out_uvs.push(src_uvs[i * 2])
          out_uvs.push(src_uvs[i * 2 + 1])
        }
        None => {
          out_uvs.push(0.0)
          out_uvs.push(0.0)
        }
      }
    }
  } else {
    for _ in 0..<3 {
      out_uvs.push(0.0)
      out_uvs.push(0.0)
    }
  }
  out_indices.push(base.reinterpret_as_uint())
  out_indices.push((base + 1).reinterpret_as_uint())
  out_indices.push((base + 2).reinterpret_as_uint())
}

///|
/// 行 → 非空 token 序列(空白切分,连续空白折叠)
fn obj_tokens(line : StringView) -> Array[StringView] {
  let out : Array[StringView] = []
  let start = Ref(-1)
  for (i, ch) in line.iter2() {
    let code = ch.to_int()
    if code == 32 || code == 9 || code == 13 {
      if start.val >= 0 {
        out.push(line.exact_view(start=start.val, end=i))
        start.val = -1
      }
    } else if start.val < 0 {
      start.val = i
    }
  }
  if start.val >= 0 {
    out.push(line.exact_view(start=start.val))
  }
  out
}

///| 十进制浮点解析:[-+]?(digits[.digits]?|.digits)([eE][-+]?digits)?;

///| 全串匹配,尾随垃圾返回 None(JS parseFloat 是前缀解析,这里更严,

///|
/// 非法数字按坏行容错跳过)
fn parse_double_token(s : StringView) -> Double? {
  let n = s.char_length()
  let mut i = 0
  let mut neg = false
  let mut mantissa = 0.0
  let mut digits = 0
  let mut frac_digits = 0
  let mut exp = 0
  if i < n {
    match s.unsafe_get(i).to_int() {
      43 => i = i + 1 // '+'
      45 => {
        neg = true
        i = i + 1
      }
      _ => ()
    }
  }
  while i < n && is_digit_code(s.unsafe_get(i).to_int()) {
    mantissa = mantissa * 10.0 + (s.unsafe_get(i).to_int() - 48).to_double()
    digits = digits + 1
    i = i + 1
  }
  if i < n && s.unsafe_get(i).to_int() == 46 {
    i = i + 1
    while i < n && is_digit_code(s.unsafe_get(i).to_int()) {
      mantissa = mantissa * 10.0 + (s.unsafe_get(i).to_int() - 48).to_double()
      frac_digits = frac_digits + 1
      digits = digits + 1
      i = i + 1
    }
  }
  if digits == 0 {
    return None
  }
  if i < n &&
    (s.unsafe_get(i).to_int() == 101 || s.unsafe_get(i).to_int() == 69) {
    i = i + 1
    let mut exp_neg = false
    if i < n {
      match s.unsafe_get(i).to_int() {
        43 => i = i + 1
        45 => {
          exp_neg = true
          i = i + 1
        }
        _ => ()
      }
    }
    let mut exp_digits = 0
    while i < n && is_digit_code(s.unsafe_get(i).to_int()) {
      exp = exp * 10 + (s.unsafe_get(i).to_int() - 48)
      exp_digits = exp_digits + 1
      i = i + 1
    }
    if exp_digits == 0 {
      return None
    }
    if exp_neg {
      exp = -exp
    }
  }
  if i != n {
    return None
  }
  let value = mantissa * pow10(exp - frac_digits)
  Some(if neg { -value } else { value })
}

///|
/// 有符号十进制整数解析(面索引用;全串匹配)
fn parse_int_token(s : StringView) -> Int? {
  let n = s.char_length()
  let mut i = 0
  let mut neg = false
  let mut value = 0
  let mut digits = 0
  if i < n {
    match s.unsafe_get(i).to_int() {
      43 => i = i + 1
      45 => {
        neg = true
        i = i + 1
      }
      _ => ()
    }
  }
  while i < n && is_digit_code(s.unsafe_get(i).to_int()) {
    value = value * 10 + (s.unsafe_get(i).to_int() - 48)
    digits = digits + 1
    i = i + 1
  }
  if digits == 0 || i != n {
    return None
  }
  Some(if neg { -value } else { value })
}

///|
/// 10 的整数次幂(OBJ 指数位长个位数,循环足够)
fn pow10(e : Int) -> Double {
  let mut r = 1.0
  if e >= 0 {
    for _ in 0..<e {
      r = r * 10.0
    }
    r
  } else {
    for _ in 0..<-e {
      r = r * 10.0
    }
    1.0 / r
  }
}

///|
/// ASCII 数字码判定
fn is_digit_code(code : Int) -> Bool {
  code >= 48 && code <= 57
}
