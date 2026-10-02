// f32/u32 小端字节编码:顶点、索引与 uniform 上传的基础设施。
// Bytes 不可变,编码经 FixedArray[Byte] 中转。

///| 把 Double 以 f32 小端写入缓冲指定偏移
fn write_f32(buf : FixedArray[Byte], off : Int, v : Double) -> Unit {
  let bits = Float::from_double(v).reinterpret_as_uint()
  buf.set(off, (bits & 0xFFU).to_byte())
  buf.set(off + 1, ((bits >> 8) & 0xFFU).to_byte())
  buf.set(off + 2, ((bits >> 16) & 0xFFU).to_byte())
  buf.set(off + 3, ((bits >> 24) & 0xFFU).to_byte())
}

fn to_bytes(fa : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(fa[:])
}

///| Double 数组转 f32 字节序列
fn f32_array_bytes(arr : Array[Double]) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(arr.length() * 4, b'0')
  for i in 0..<arr.length() {
    write_f32(b, i * 4, arr[i])
  }
  to_bytes(b)
}

///| 索引数组转 u32 小端字节序列
fn u32_array_bytes(arr : Array[UInt]) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(arr.length() * 4, b'0')
  for i in 0..<arr.length() {
    let v = arr[i]
    b.set(i * 4, (v & 0xFFU).to_byte())
    b.set(i * 4 + 1, ((v >> 8) & 0xFFU).to_byte())
    b.set(i * 4 + 2, ((v >> 16) & 0xFFU).to_byte())
    b.set(i * 4 + 3, ((v >> 24) & 0xFFU).to_byte())
  }
  to_bytes(b)
}

///| uniform 缓冲:先 blit 矩阵再写颜色
fn uniform_bytes(mvp : @math3d.Matrix4, color : @math3d.Color) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(80, b'0')
  let m = mvp.e
  for i in 0..<16 {
    write_f32(b, i * 4, m[i])
  }
  write_f32(b, 64, color.r)
  write_f32(b, 68, color.g)
  write_f32(b, 72, color.b)
  write_f32(b, 76, 1.0)
  to_bytes(b)
}
