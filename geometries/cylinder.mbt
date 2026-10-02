// three.js CylinderGeometry / ConeGeometry 迁移:圆柱、圆台、圆锥(顶半径 0)。

///| 端盖生成(cylinder 辅助):每个扇面一份中心顶点(每面一份 UV)+ 外环顶点,
///| top 朝 +Y、bottom 朝 -Y,扇面绕向相反;返回新的顶点索引游标
fn cylinder_cap(
  top : Bool,
  radius : Double,
  half_height : Double,
  radial_segments : Int,
  theta_start : Double,
  theta_length : Double,
  positions : Array[Double],
  normals : Array[Double],
  uvs : Array[Double],
  indices : Array[UInt],
  index : Int,
) -> Int {
  let mut index = index
  let center_index_start = index
  let sign : Double = if top { 1.0 } else { -1.0 }
  // 中心顶点:每扇面一份
  for _ in 1..=radial_segments {
    positions.push(0.0)
    positions.push(half_height * sign)
    positions.push(0.0)
    normals.push(0.0)
    normals.push(sign)
    normals.push(0.0)
    uvs.push(0.5)
    uvs.push(0.5)
    index = index + 1
  }
  let center_index_end = index
  // 外环顶点
  for x in 0..=radial_segments {
    let u = x.to_double() / radial_segments.to_double()
    let theta = u * theta_length + theta_start
    let cos_theta = @math.cos(theta)
    let sin_theta = @math.sin(theta)
    positions.push(radius * sin_theta)
    positions.push(half_height * sign)
    positions.push(radius * cos_theta)
    normals.push(0.0)
    normals.push(sign)
    normals.push(0.0)
    uvs.push(cos_theta * 0.5 + 0.5)
    uvs.push(sin_theta * 0.5 * sign + 0.5)
    index = index + 1
  }
  // 扇面索引:top 与 bottom 三角绕向相反
  for x in 0..<radial_segments {
    let c = center_index_start + x
    let i = center_index_end + x
    if top {
      indices.push(Int::reinterpret_as_uint(i))
      indices.push(Int::reinterpret_as_uint(i + 1))
      indices.push(Int::reinterpret_as_uint(c))
    } else {
      indices.push(Int::reinterpret_as_uint(i + 1))
      indices.push(Int::reinterpret_as_uint(i))
      indices.push(Int::reinterpret_as_uint(c))
    }
  }
  index
}

///| CylinderGeometry:圆柱/圆台。参数对应 three.js CylinderGeometry:
///| radius_top、radius_bottom、height、radial_segments(默认 32)、height_segments(默认 1)、
///| open_ended(默认 false)、theta_start(默认 0)、theta_length(默认 2π)
pub fn cylinder(
  radius_top : Double,
  radius_bottom : Double,
  height : Double,
  radial_segments : Int,
  height_segments : Int,
  open_ended : Bool,
  theta_start : Double,
  theta_length : Double,
) -> @core.BufferGeometry {
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  let mut index : Int = 0
  // 每行顶点索引(torso 索引网格)
  let index_array : Array[Array[Int]] = []
  let half_height = height / 2.0
  // 侧面法线的坡度补偿(圆台侧斜)
  let slope = (radius_bottom - radius_top) / height
  // 侧面:顶点/法线/uv
  for y in 0..=height_segments {
    let row : Array[Int] = []
    let v = y.to_double() / height_segments.to_double()
    let radius = v * (radius_bottom - radius_top) + radius_top
    for x in 0..=radial_segments {
      let u = x.to_double() / radial_segments.to_double()
      let theta = u * theta_length + theta_start
      let sin_theta = @math.sin(theta)
      let cos_theta = @math.cos(theta)
      positions.push(radius * sin_theta)
      positions.push(-v * height + half_height)
      positions.push(radius * cos_theta)
      let normal = @math3d.Vector3::new(sin_theta, slope, cos_theta).normalize()
      normals.push(normal.x)
      normals.push(normal.y)
      normals.push(normal.z)
      uvs.push(u)
      uvs.push(1.0 - v)
      row.push(index)
      index = index + 1
    }
    index_array.push(row)
  }
  // 侧面索引:顶行/底行按端半径退化裁剪
  for x in 0..<radial_segments {
    for y in 0..<height_segments {
      let a = index_array[y][x]
      let b = index_array[y + 1][x]
      let c = index_array[y + 1][x + 1]
      let d = index_array[y][x + 1]
      if radius_top > 0.0 || y != 0 {
        indices.push(Int::reinterpret_as_uint(a))
        indices.push(Int::reinterpret_as_uint(b))
        indices.push(Int::reinterpret_as_uint(d))
      }
      if radius_bottom > 0.0 || y != height_segments - 1 {
        indices.push(Int::reinterpret_as_uint(b))
        indices.push(Int::reinterpret_as_uint(c))
        indices.push(Int::reinterpret_as_uint(d))
      }
    }
  }
  // 端盖:闭合且对应端半径 > 0 时生成
  if !open_ended {
    if radius_top > 0.0 {
      index = cylinder_cap(
        true,
        radius_top,
        half_height,
        radial_segments,
        theta_start,
        theta_length,
        positions,
        normals,
        uvs,
        indices,
        index,
      )
    }
    if radius_bottom > 0.0 {
      index = cylinder_cap(
        false,
        radius_bottom,
        half_height,
        radial_segments,
        theta_start,
        theta_length,
        positions,
        normals,
        uvs,
        indices,
        index,
      )
    }
  }
  let geometry : @core.BufferGeometry = { positions, normals, uvs, indices }
  geometry
}

///| ConeGeometry:圆锥(= cylinder 顶半径 0 的特化,three.js ConeGeometry 同式)。
///| 参数:radius、height、radial_segments(默认 32)、height_segments(默认 1)、
///| open_ended(默认 false)、theta_start(默认 0)、theta_length(默认 2π)
pub fn cone(
  radius : Double,
  height : Double,
  radial_segments : Int,
  height_segments : Int,
  open_ended : Bool,
  theta_start : Double,
  theta_length : Double,
) -> @core.BufferGeometry {
  cylinder(
    0.0,
    radius,
    height,
    radial_segments,
    height_segments,
    open_ended,
    theta_start,
    theta_length,
  )
}
