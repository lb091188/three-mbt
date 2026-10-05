// 16 位灰度 PNG 精确解码(高程图专用)。移植自 steel-front 仓
// moonbit/v9_image(阶段0-V9 实验):mizchi/image 的 decode_png 不支持
// 16 位(png_color.mbt 兜底 UnsupportedFeature),而高程图语义
// v16 = R*256+G 必须精确 —— 与服务端 server.js 的手解实现逐位一致,
// 客户端/服务器高度才不分叉。仅支持非交错、灰度、16 位、5 种 filter。

///| 读 4 字节大端 u32
fn be32(b : Bytes, p : Int) -> Int {
  (b[p].to_int() << 24) | (b[p + 1].to_int() << 16) |
  (b[p + 2].to_int() << 8) | b[p + 3].to_int()
}

///| PNG16 灰度精确解码:返回 (width, height, 像素 u16 行主序数组)
///| 仅支持 color_type=0(灰度)、bit_depth=16、非交错 —— 高程图全是这种
pub fn decode_png16_gray(
  raw : Bytes
) -> (Int, Int, FixedArray[Int]) raise Error {
  let mut width = 0
  let mut height = 0
  let idat : Array[(Int, Int)] = [] // (start, len)
  let mut pos = 8 // 跳过签名
  let mut seen_ihdr = false
  while pos + 8 <= raw.length() {
    let len = be32(raw, pos)
    let t0 = raw[pos + 4].to_int()
    let t1 = raw[pos + 5].to_int()
    let t2 = raw[pos + 6].to_int()
    let t3 = raw[pos + 7].to_int()
    let data_start = pos + 8
    if t0 == 0x49 && t1 == 0x48 && t2 == 0x44 && t3 == 0x52 { // IHDR
      width = be32(raw, data_start)
      height = be32(raw, data_start + 4)
      let bit_depth = raw[data_start + 8].to_int()
      let color_type = raw[data_start + 9].to_int()
      let interlace = raw[data_start + 12].to_int()
      if bit_depth != 16 || color_type != 0 {
        raise Failure(
          "decode_png16_gray 只管 16 位灰度: 实际 depth=\{bit_depth} color=\{color_type}",
        )
      }
      if interlace != 0 {
        raise Failure("不支持交错 PNG")
      }
      seen_ihdr = true
    } else if t0 == 0x49 && t1 == 0x44 && t2 == 0x41 && t3 == 0x54 { // IDAT
      idat.push((data_start, len))
    }
    pos += 12 + len // len + type + crc
  }
  if not(seen_ihdr) {
    raise Failure("没有 IHDR")
  }
  if idat.is_empty() {
    raise Failure("没有 IDAT")
  }
  // IDAT 串接
  let mut total = 0
  for c in idat {
    total += c.1
  }
  let joined = FixedArray::make(total, b'\x00')
  let mut off = 0
  for c in idat {
    joined.blit_from_bytes(off, raw, c.0, c.1)
    off += c.1
  }
  let inflated = @zlib.zlib_decompress(Bytes::from_array(joined)) catch {
    e => raise Failure("zlib inflate 失败: \{e}")
  }
  // 反滤波:每行 = 1 filter 字节 + width*2 数据;bpp=2(16 位灰度)
  let bpp = 2
  let stride = width * 2
  if inflated.length() != height * (1 + stride) {
    raise Failure(
      "尺寸不符: 期望 \{height * (1 + stride)} 实得 \{inflated.length()}",
    )
  }
  let pixels = FixedArray::make(width * height, 0)
  let cur : FixedArray[Byte] = FixedArray::make(stride, b'\x00')
  let prev : FixedArray[Byte] = FixedArray::make(stride, b'\x00')
  for y in 0..<height {
    let base = y * (1 + stride)
    let ft = inflated[base].to_int()
    for i in 0..<stride {
      let x = inflated[base + 1 + i].to_int() & 0xFF
      let a = if i >= bpp { cur[i - bpp].to_int() & 0xFF } else { 0 }
      let b = prev[i].to_int() & 0xFF
      let v : Int = match ft {
        0 => x
        1 => (x + a) & 0xFF // Sub
        2 => (x + b) & 0xFF // Up
        3 => (x + ((a + b) >> 1)) & 0xFF // Average
        4 => { // Paeth
          let c = if i >= bpp {
            prev[i - bpp].to_int() & 0xFF
          } else {
            0
          }
          let p = a + b - c
          let pa = if p - a < 0 { a - p } else { p - a }
          let pb = if p - b < 0 { b - p } else { p - b }
          let pc = if p - c < 0 { c - p } else { p - c }
          let pr = if pa <= pb && pa <= pc {
            a
          } else if pb <= pc {
            b
          } else {
            c
          }
          (x + pr) & 0xFF
        }
        _ => raise Failure("未知 filter 类型 \{ft}")
      }
      cur[i] = v.to_byte()
    }
    for x in 0..<width {
      pixels[y * width + x] =
        ((cur[x * 2].to_int() & 0xFF) << 8) | (cur[x * 2 + 1].to_int() & 0xFF)
    }
    for i in 0..<stride {
      prev[i] = cur[i]
    }
  }
  (width, height, pixels)
}

///| 高程图加载:PNG16 灰度解码 → (w, h, u16 像素)。
///| 配套 BufferGeometry::heightfield 把像素变成地形网格(见 core/geometry.mbt)
pub fn load_heightmap_png16(
  bytes : Bytes
) -> (Int, Int, FixedArray[Int]) raise Error {
  decode_png16_gray(bytes)
}
