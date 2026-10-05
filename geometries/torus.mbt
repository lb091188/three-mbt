// three.js TorusGeometry 迁移:圆环面(管圆绕主圆扫掠)。

///| TorusGeometry:圆环面。参数对应 three.js TorusGeometry:
///| radius(默认 1)、tube(默认 0.4)、radial_segments(默认 12)、tubular_segments(默认 48)、
///| arc(默认 2π)、theta_start(默认 0)、theta_length(默认 2π)
pub fn torus(
  radius : Double,
  tube : Double,
  radial_segments : Int,
  tubular_segments : Int,
  arc : Double,
  theta_start : Double,
  theta_length : Double,
) -> @core.BufferGeometry {
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  // 顶点/法线/uv:先管截面(radial),后主圆(tubular)
  for j in 0..=radial_segments {
    let v = theta_start + j.to_double() / radial_segments.to_double() * theta_length
    let cos_v = @math.cos(v)
    let sin_v = @math.sin(v)
    for i in 0..=tubular_segments {
      let u = i.to_double() / tubular_segments.to_double() * arc
      let cos_u = @math.cos(u)
      let sin_u = @math.sin(u)
      let x = (radius + tube * cos_v) * cos_u
      let y = (radius + tube * cos_v) * sin_u
      let z = tube * sin_v
      positions.push(x)
      positions.push(y)
      positions.push(z)
      // 法线 = 顶点 - 主圆上的环心
      let normal = @math3d.Vector3::new(
        x - radius * cos_u,
        y - radius * sin_u,
        z,
      ).normalize()
      normals.push(normal.x)
      normals.push(normal.y)
      normals.push(normal.z)
      uvs.push(i.to_double() / tubular_segments.to_double())
      uvs.push(j.to_double() / radial_segments.to_double())
    }
  }
  // 索引:四边形拆两三角
  for j in 1..=radial_segments {
    for i in 1..=tubular_segments {
      let a = (tubular_segments + 1) * j + i - 1
      let b = (tubular_segments + 1) * (j - 1) + i - 1
      let c = (tubular_segments + 1) * (j - 1) + i
      let d = (tubular_segments + 1) * j + i
      indices.push(Int::reinterpret_as_uint(a))
      indices.push(Int::reinterpret_as_uint(b))
      indices.push(Int::reinterpret_as_uint(d))
      indices.push(Int::reinterpret_as_uint(b))
      indices.push(Int::reinterpret_as_uint(c))
      indices.push(Int::reinterpret_as_uint(d))
    }
  }
  let geometry : @core.BufferGeometry = { positions, normals, uvs, colors: [], indices }
  geometry
}
