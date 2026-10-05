// three.js Sprite 迁移(A8):始终面向相机的四边形。
// 数据层 = 精灵单位四边形几何 + 公告板朝向计算(相机世界矩阵旋转列);
// 渲染层按 Material.kind==3 分派到公告板透明管线(右/上轴经 uniform 下发,
// 着色器按 corner*axis 组装世界坐标 —— 与本文件的 CPU 公式逐项对应)。
// three.js 语义参照 r186 Sprite/SpriteMaterial:center 锚点(默认 0.5,0.5)、
// rotation 屏面内旋转、scale.x/scale.y 即世界尺寸。

///| 精灵单位四边形几何:角点 ±0.5(左下/右下/右上/左上),uv 全图同序,

///| 双三角索引;无法线(不参与光照)。世界尺寸 = 节点 scale,由渲染层

///|
/// 经 uniform 下发,几何保持单位大小可被任意精灵共享。
pub fn BufferGeometry::sprite_quad() -> BufferGeometry {
  {
    positions: [-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.5, 0.5, 0.0, -0.5, 0.5, 0.0],
    normals: [],
    uvs: [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
    colors: [],
    indices: [0, 1, 2, 0, 2, 3],
  }
}

///| 公告板朝向:从相机世界矩阵提取右/上轴(旋转列归一;相机带缩放时

///| 列含缩放分量,归一剔除)。精灵四边形按 right×size_x、up×size_y

///| 展开在世界空间,法线恒指向相机 —— three.js 把精灵对齐到 modelView

///|
/// 旋转的同一约定(视图系 XY = 世界系相机的右/上)。
pub fn billboard_axes(
  cam_world : @math3d.Matrix4,
) -> (@math3d.Vector3, @math3d.Vector3) {
  let e = cam_world.e
  // 列主序:第 0 列 = 相机右轴,第 1 列 = 相机上轴
  let right = @math3d.Vector3::new(e[0], e[1], e[2]).normalize()
  let up = @math3d.Vector3::new(e[4], e[5], e[6]).normalize()
  (right, up)
}

///| 相机便捷版:先刷新相机节点世界矩阵再取轴(渲染前 update_matrix_world

///|
/// 已调过时是无重复开销的幂等操作)
pub fn billboard_axes_of(
  camera : PerspectiveCamera,
) -> (@math3d.Vector3, @math3d.Vector3) {
  camera.obj.update_world_matrix(true, false)
  billboard_axes(camera.obj.matrix_world)
}

///| 精灵四角的屏面内对齐偏移(three.js alignedPosition 同式:

///| offset = corner + center - 0.5,corner ∈ ±0.5)。返回 4 个 (ox,oy)

///|
/// 与 sprite_quad 顶点序一致(左下/右下/右上/左上)。
pub fn sprite_aligned_offsets(
  anchor : @math3d.Vector2,
) -> Array[(Double, Double)] {
  let dx = anchor.x - 0.5
  let dy = anchor.y - 0.5
  [
    (-0.5 + dx, -0.5 + dy),
    (0.5 + dx, -0.5 + dy),
    (0.5 + dx, 0.5 + dy),
    (-0.5 + dx, 0.5 + dy),
  ]
}

///| 计算精灵世界空间四角(center=节点世界位置,size=节点 scale,

///| right/up=公告板轴,anchor=SpriteMaterial.center)。返回顺序与

///|
/// sprite_quad 顶点序一致;着色器侧的 GPU 组装与本函数同式。
pub fn sprite_world_quad(
  center : @math3d.Vector3,
  size_x : Double,
  size_y : Double,
  right : @math3d.Vector3,
  up : @math3d.Vector3,
  anchor : @math3d.Vector2,
) -> Array[@math3d.Vector3] {
  let corners : Array[@math3d.Vector3] = []
  for i, off in sprite_aligned_offsets(anchor) {
    let (ox, oy) = off
    ignore(i)
    corners.push(
      center
      .add(right.multiply_scalar(ox * size_x))
      .add(up.multiply_scalar(oy * size_y)),
    )
  }
  corners
}

///| 把一个公告板四角直接写进 positions 数组(粒子系统动态几何的热路径:

///| 避免逐粒子分配;vertex_base 为四角首顶点下标,写 12 个 Double)。

///| world 偏移 = center + right*(ox*size_x) + up*(oy*size_y),与

///|
/// sprite_world_quad 同式。
pub fn sprite_write_quad(
  positions : Array[Double],
  vertex_base : Int,
  center : @math3d.Vector3,
  size_x : Double,
  size_y : Double,
  right : @math3d.Vector3,
  up : @math3d.Vector3,
) -> Unit {
  let offs = [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]
  for j, off in offs {
    let (ox, oy) = off
    let base = (vertex_base + j) * 3
    positions[base] = center.x + right.x * ox * size_x + up.x * oy * size_y
    positions[base + 1] = center.y + right.y * ox * size_x + up.y * oy * size_y
    positions[base + 2] = center.z + right.z * ox * size_x + up.z * oy * size_y
  }
}

///| 锚点平移量:把 anchor≠0.5 的偏移折进均匀中心(渲染层填 uniform 用,

///|
/// 与 sprite_aligned_offsets 的 dx/dy 同源)。
pub fn sprite_anchor_shift(
  anchor : @math3d.Vector2,
  size_x : Double,
  size_y : Double,
  right : @math3d.Vector3,
  up : @math3d.Vector3,
) -> @math3d.Vector3 {
  right
  .multiply_scalar((anchor.x - 0.5) * size_x)
  .add(up.multiply_scalar((anchor.y - 0.5) * size_y))
}
