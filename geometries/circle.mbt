// three.js CircleGeometry 迁移:圆盘/正多边形/扇形(法线 +Z)。

///| CircleGeometry:圆盘,由中心扇出的三角形构成(逆时针,segments 下限 3)。
///| 参数:radius(默认 1)、segments(默认 32)、theta_start(默认 0)、theta_length(默认 2π)
pub fn circle(
  radius : Double,
  segments : Int,
  theta_start : Double,
  theta_length : Double,
) -> @core.BufferGeometry {
  let segments = if segments < 3 { 3 } else { segments }
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  // 中心点
  positions.push(0.0)
  positions.push(0.0)
  positions.push(0.0)
  normals.push(0.0)
  normals.push(0.0)
  normals.push(1.0)
  uvs.push(0.5)
  uvs.push(0.5)
  // 外圈顶点(s = segments 时与 s = 0 在完整圆下重合,保留独立顶点)
  for s in 0..=segments {
    let segment = theta_start + s.to_double() / segments.to_double() * theta_length
    let x = radius * @math.cos(segment)
    let y = radius * @math.sin(segment)
    positions.push(x)
    positions.push(y)
    positions.push(0.0)
    normals.push(0.0)
    normals.push(0.0)
    normals.push(1.0)
    uvs.push((x / radius + 1.0) / 2.0)
    uvs.push((y / radius + 1.0) / 2.0)
  }
  // 扇面索引
  for i in 1..=segments {
    indices.push(Int::reinterpret_as_uint(i))
    indices.push(Int::reinterpret_as_uint(i + 1))
    indices.push(0)
  }
  let geometry : @core.BufferGeometry = { positions, normals, uvs, colors: [], indices }
  geometry
}
