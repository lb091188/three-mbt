// three.js BufferGeometry 迁移:顶点属性与索引(interleaved 后续按需)。

///| 顶点几何(position/normals/uvs/colors 交错前为独立数组)
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

///| 空几何
pub fn BufferGeometry::empty() -> BufferGeometry {
  { positions: [], normals: [], uvs: [], colors: [], indices: [] }
}

///| 顶点数
pub fn BufferGeometry::vertex_count(self : BufferGeometry) -> Int {
  self.positions.length() / 3
}

///| 索引数(三角形数 ×3)
pub fn BufferGeometry::index_count(self : BufferGeometry) -> Int {
  self.indices.length()
}

///| BoxGeometry:轴对齐立方体(three.js BoxGeometry 同拓扑,24 顶点/36 索引;
///| 每面 UV 与 three.js 同布局:四角 (0,1)(1,1)(1,0)(0,0) 对应顶点顺序)
pub fn BufferGeometry::box(w : Double, h : Double, d : Double) -> BufferGeometry {
  let x = w / 2.0
  let y = h / 2.0
  let z = d / 2.0
  let positions : Array[Double] = []
  let normals : Array[Double] = []
  let uvs : Array[Double] = []
  let indices : Array[UInt] = []
  // 每面:4 顶点(两三角)——(法线, 四角)
  let faces : Array[(Double, Double, Double, Array[(Double, Double, Double)])] = [
    (0.0, 0.0, 1.0, [
      (-x, -y, z),
      (x, -y, z),
      (x, y, z),
      (-x, y, z),
    ]), // 前 +Z
    (0.0, 0.0, -1.0, [
      (x, -y, -z),
      (-x, -y, -z),
      (-x, y, -z),
      (x, y, -z),
    ]), // 后 -Z
    (1.0, 0.0, 0.0, [
      (x, -y, z),
      (x, -y, -z),
      (x, y, -z),
      (x, y, z),
    ]), // 右 +X
    (-1.0, 0.0, 0.0, [
      (-x, -y, -z),
      (-x, -y, z),
      (-x, y, z),
      (-x, y, -z),
    ]), // 左 -X
    (0.0, 1.0, 0.0, [
      (-x, y, z),
      (x, y, z),
      (x, y, -z),
      (-x, y, -z),
    ]), // 上 +Y
    (0.0, -1.0, 0.0, [
      (-x, -y, -z),
      (x, -y, -z),
      (x, -y, z),
      (-x, -y, z),
    ]), // 下 -Y
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
  { positions, normals, uvs, colors: [], indices }
}

///| PlaneGeometry:XY 平面(朝 +Z),seg 1×1;
///| UV 与 three.js 同布局:四顶点 (0,0)(1,0)(1,1)(0,1)
pub fn BufferGeometry::plane(w : Double, h : Double) -> BufferGeometry {
  let x = w / 2.0
  let y = h / 2.0
  {
    positions: [
      -x, -y, 0.0, x, -y, 0.0, x, y, 0.0, -x, y, 0.0,
    ],
    normals: [
      0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
    ],
    uvs: [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
    colors: [],
    indices: [ 0, 1, 2, 0, 2, 3, ],
  }
}
