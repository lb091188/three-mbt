// three.js BufferGeometry 迁移:顶点属性与索引(interleaved 后续按需)。

///|
/// 顶点几何(position/normals/uvs/colors 交错前为独立数组)
pub(all) struct BufferGeometry {
  /// 顶点位置 xyz 连续
  positions : Array[Double]
  /// 法线 xyz 连续(可选,长度与 positions 相等或为空)
  normals : Array[Double]
  /// 纹理坐标 uv 连续(可选,长度为顶点数×2 或为空;lit 管线缺省补 (0,0))
  uvs : Array[Double]
  /// 顶点色 rgb 连续(可选,长度为顶点数×3 或为空;材质 vertex_colors=true 时乘进主色,
  /// 管线侧缺省补 (1,1,1) 白 —— 与 three.js 默认顶点色语义一致)
  colors : Array[Double]
  /// 顶点索引(空 = 非索引化绘制)
  indices : Array[UInt]
}

///|
/// 空几何
pub fn BufferGeometry::empty() -> BufferGeometry {
  { positions: [], normals: [], uvs: [], colors: [], indices: [], }
}

///|
/// 从位置数组构建非索引化几何(xyz 连续;线几何等按顶点序绘制的场景)
pub fn BufferGeometry::from_positions(
  positions : Array[Double],
) -> BufferGeometry {
  { positions, normals: [], uvs: [], colors: [], indices: [], }
}

///| 运行时替换位置数组(内容覆写;顶点数变化后由渲染层 update_vertices

///|
/// 检测尺寸失配并按新数组重建 GPU 缓冲)
pub fn BufferGeometry::set_positions(
  self : BufferGeometry,
  positions : Array[Double],
) -> Unit {
  self.positions.clear()
  for p in positions {
    self.positions.push(p)
  }
}

///|
/// 运行时设置单个顶点位置(动态折线每帧改端点;越界静默忽略)
pub fn BufferGeometry::set_vertex(
  self : BufferGeometry,
  index : Int,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  let n = self.vertex_count()
  if index >= 0 && index < n {
    self.positions[index * 3] = x
    self.positions[index * 3 + 1] = y
    self.positions[index * 3 + 2] = z
  }
}

///|
/// 运行时替换顶点色数组(rgb 连续,长度应为顶点数×3)
pub fn BufferGeometry::set_colors(
  self : BufferGeometry,
  colors : Array[Double],
) -> Unit {
  self.colors.clear()
  for c in colors {
    self.colors.push(c)
  }
}

///|
/// 顶点数
pub fn BufferGeometry::vertex_count(self : BufferGeometry) -> Int {
  self.positions.length() / 3
}

///|
/// 索引数(三角形数 ×3)
pub fn BufferGeometry::index_count(self : BufferGeometry) -> Int {
  self.indices.length()
}

///| BoxGeometry:轴对齐立方体(three.js BoxGeometry 同拓扑,24 顶点/36 索引;

///|
/// 每面 UV 与 three.js 同布局:四角 (0,1)(1,1)(1,0)(0,0) 对应顶点顺序)
pub fn BufferGeometry::box(
  w : Double,
  h : Double,
  d : Double,
) -> BufferGeometry {
  let x = w / 2.0
  let y = h / 2.0
  let z = d / 2.0
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  // 每面:4 顶点(两三角)——(法线, 四角)
  let faces : Array[(Double, Double, Double, Array[(Double, Double, Double)])] = [
    (0.0, 0.0, 1.0, [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]), // 前 +Z
    (0.0, 0.0, -1.0, [(x, -y, -z), (-x, -y, -z), (-x, y, -z), (x, y, -z)]), // 后 -Z
    (1.0, 0.0, 0.0, [(x, -y, z), (x, -y, -z), (x, y, -z), (x, y, z)]), // 右 +X
    (-1.0, 0.0, 0.0, [(-x, -y, -z), (-x, -y, z), (-x, y, z), (-x, y, -z)]), // 左 -X
    (0.0, 1.0, 0.0, [(-x, y, z), (x, y, z), (x, y, -z), (-x, y, -z)]), // 上 +Y
    (0.0, -1.0, 0.0, [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z)]), // 下 -Y
  ]
  // 每面四角 UV(three.js buildPlane:左下→右下→右上→左上 的 (u,v) 组)
  let face_uvs : Array[(Double, Double)] = [
    (0.0, 0.0),
    (1.0, 0.0),
    (1.0, 1.0),
    (0.0, 1.0),
  ]
  let mut base : UInt = 0U
  for i, face in faces {
    let (nx, ny, nz, quad) = face
    for j, corner in quad {
      let (px, py, pz) = corner
      positions.push(px)
      positions.push(py)
      positions.push(pz)
      normals.push(nx)
      normals.push(ny)
      normals.push(nz)
      let (u, v) = face_uvs[j]
      uvs.push(u)
      uvs.push(v)
    }
    ignore(i)
    indices.push(base)
    indices.push(base + 1)
    indices.push(base + 2)
    indices.push(base)
    indices.push(base + 2)
    indices.push(base + 3)
    base = base + 4
  }
  { positions, normals, uvs, colors: [], indices, }
}

///| PlaneGeometry:XY 平面(朝 +Z),seg 1×1;

///|
/// UV 与 three.js 同布局:四顶点 (0,0)(1,0)(1,1)(0,1)
pub fn BufferGeometry::plane(w : Double, h : Double) -> BufferGeometry {
  let x = w / 2.0
  let y = h / 2.0
  {
    positions: [-x, -y, 0.0, x, -y, 0.0, x, y, 0.0, -x, y, 0.0],
    normals: [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
    uvs: [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
    colors: [],
    indices: [0, 1, 2, 0, 2, 3],
  }
}

///| HeightfieldGeometry:XZ 细分地形网格(水平放置,朝 +Y)。

///| 顶点 (segs_x+1)×(segs_z+1) 个,网格节点 (i,j) 的位置为

///| x = -width/2 + i/segs_x*width、z = -depth/2 + j/segs_z*depth、

///| y = sample(i, j) —— sample 由调用方提供(高程图双线性采样、程序地形皆可);

///| 顶点法线 = 邻面法线累积平均(逐三角面法线求和后归一,共点三角加权同

///| three.js computeVertexNormals 语义);

///| UV = 世界坐标 / uv_scale(u=x/scale, v=z/scale),配 Repeat 环绕平铺。

///| 三角绕序 (i,j)→(i,j+1)→(i+1,j) / (i+1,j)→(i,j+1)→(i+1,j+1),

///|
/// CCW 朝上,与 lit 管线 back-cull 配合可见面为上表面。
pub fn BufferGeometry::heightfield(
  width : Double,
  depth : Double,
  segs_x : Int,
  segs_z : Int,
  sample : (Int, Int) -> Double,
  uv_scale : Double,
) -> BufferGeometry {
  let nx = segs_x + 1
  let nz = segs_z + 1
  let positions : Array[Double] = []
  let uvs : Array[Double] = []
  // 网格节点世界 Y 先采一遍(法线累积与角点校验共用)
  let ys : Array[Double] = Array::make(nx * nz, 0.0)
  for j in 0..<nz {
    for i in 0..<nx {
      ys[j * nx + i] = sample(i, j)
    }
  }
  for j in 0..<nz {
    for i in 0..<nx {
      let x = -width / 2.0 +
        Double::from_int(i) / Double::from_int(segs_x) * width
      let z = -depth / 2.0 +
        Double::from_int(j) / Double::from_int(segs_z) * depth
      positions.push(x)
      positions.push(ys[j * nx + i])
      positions.push(z)
      uvs.push(x / uv_scale)
      uvs.push(z / uv_scale)
    }
  }
  // 索引(两三角/格)与法线累积
  let indices : Array[UInt] = []
  let acc : Array[Double] = Array::make(nx * nz * 3, 0.0)
  for j in 0..<segs_z {
    for i in 0..<segs_x {
      let v00 = j * nx + i
      let v01 = (j + 1) * nx + i
      let v10 = j * nx + i + 1
      let v11 = (j + 1) * nx + i + 1
      indices.push(v00.to_uint())
      indices.push(v01.to_uint())
      indices.push(v10.to_uint())
      indices.push(v10.to_uint())
      indices.push(v01.to_uint())
      indices.push(v11.to_uint())
      heightfield_accumulate(positions, acc, v00, v01, v10)
      heightfield_accumulate(positions, acc, v10, v01, v11)
    }
  }
  let normals : Array[Double] = []
  for k in 0..<(nx * nz) {
    let x = acc[k * 3]
    let y = acc[k * 3 + 1]
    let z = acc[k * 3 + 2]
    let len = (x * x + y * y + z * z).sqrt()
    if len < 0.0000001 {
      normals.push(0.0)
      normals.push(1.0) // 退化面(共线)兜底朝上
      normals.push(0.0)
    } else {
      normals.push(x / len)
      normals.push(y / len)
      normals.push(z / len)
    }
  }
  { positions, normals, uvs, colors: [], indices, }
}

///| heightfield 内部:三角 (a,b,c) 的未归一面法线(叉积,面积加权)

///|
/// 累加到三顶点的法线累加器 acc(行主序 xyz 连排)
fn heightfield_accumulate(
  positions : Array[Double],
  acc : Array[Double],
  a : Int,
  b : Int,
  c : Int,
) -> Unit {
  let ax = positions[a * 3]
  let ay = positions[a * 3 + 1]
  let az = positions[a * 3 + 2]
  let e1x = positions[b * 3] - ax
  let e1y = positions[b * 3 + 1] - ay
  let e1z = positions[b * 3 + 2] - az
  let e2x = positions[c * 3] - ax
  let e2y = positions[c * 3 + 1] - ay
  let e2z = positions[c * 3 + 2] - az
  // 叉积 e1×e2 = 未归一面法线(除以 2 对后续归一无关)
  let fx = e1y * e2z - e1z * e2y
  let fy = e1z * e2x - e1x * e2z
  let fz = e1x * e2y - e1y * e2x
  for k in [a, b, c] {
    acc[k * 3] += fx
    acc[k * 3 + 1] += fy
    acc[k * 3 + 2] += fz
  }
}
