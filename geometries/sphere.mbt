// three.js SphereGeometry 迁移:球面,含极点行 UV 半格偏移。

///| SphereGeometry:球面。参数对应 three.js SphereGeometry:
///| radius、width_segments(默认 32,下限 3)、height_segments(默认 16,下限 2)、
///| phi_start(默认 0)、phi_length(默认 2π)、theta_start(默认 0)、theta_length(默认 π)
pub fn sphere(
  radius : Double,
  width_segments : Int,
  height_segments : Int,
  phi_start : Double,
  phi_length : Double,
  theta_start : Double,
  theta_length : Double,
) -> @core.BufferGeometry {
  let width_segments = if width_segments < 3 { 3 } else { width_segments }
  let height_segments = if height_segments < 2 { 2 } else { height_segments }
  let theta_end = if theta_start + theta_length < @math.PI {
    theta_start + theta_length
  } else {
    @math.PI
  }
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  let grid : Array[Array[Int]] = []
  let mut index : Int = 0
  // 顶点/法线/uv:按纬度行生成
  for iy in 0..=height_segments {
    let row : Array[Int] = []
    let v = iy.to_double() / height_segments.to_double()
    let theta = theta_start + v * theta_length
    let y = radius * @math.cos(theta)
    let ring_radius = (radius * radius - y * y).sqrt()
    // 极点行:UV 半格偏移(顶极点右移、北极点左移)
    let mut u_offset = 0.0
    if iy == 0 && theta_start == 0.0 {
      u_offset = 0.5 / width_segments.to_double()
    } else if iy == height_segments && theta_end == @math.PI {
      u_offset = -0.5 / width_segments.to_double()
    }
    for ix in 0..=width_segments {
      let u = ix.to_double() / width_segments.to_double()
      let phi = phi_start + u * phi_length
      let x = -ring_radius * @math.cos(phi)
      let z = ring_radius * @math.sin(phi)
      positions.push(x)
      positions.push(y)
      positions.push(z)
      let normal = @math3d.Vector3::new(x, y, z).normalize()
      normals.push(normal.x)
      normals.push(normal.y)
      normals.push(normal.z)
      uvs.push(u + u_offset)
      uvs.push(1.0 - v)
      row.push(index)
      index = index + 1
    }
    grid.push(row)
  }
  // 索引:极点行三角裁剪(与 three.js 同分支)
  for iy in 0..<height_segments {
    for ix in 0..<width_segments {
      let a = grid[iy][ix + 1]
      let b = grid[iy][ix]
      let c = grid[iy + 1][ix]
      let d = grid[iy + 1][ix + 1]
      if iy != 0 || theta_start > 0.0 {
        indices.push(Int::reinterpret_as_uint(a))
        indices.push(Int::reinterpret_as_uint(b))
        indices.push(Int::reinterpret_as_uint(d))
      }
      if iy != height_segments - 1 || theta_end < @math.PI {
        indices.push(Int::reinterpret_as_uint(b))
        indices.push(Int::reinterpret_as_uint(c))
        indices.push(Int::reinterpret_as_uint(d))
      }
    }
  }
  let geometry : @core.BufferGeometry = { positions, normals, uvs, colors: [], indices }
  geometry
}
