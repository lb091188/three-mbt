// three.js Mesh 迁移:Object3D + geometry + material。

///|
/// 渲染组件(挂在 Object3D.mesh 上)
pub(all) struct Mesh {
  geometry : BufferGeometry
  material : Material
  /// 是否投射阴影(three.js castShadow;默认 true,比 three.js 默认激进)
  mut cast_shadow : Bool
  /// 是否接收阴影(three.js receiveShadow;默认 true)
  mut receive_shadow : Bool
  /// 绘制拓扑(three.js draw mode):0=三角面(Mesh 默认)、
  /// 1=折线条带 LINE_STRIP(Line)、2=独立线段 LINE_LIST(LineSegments)
  topology : Int
}

///|
/// 构造网格节点(geometry+material 挂到新 Object3D;阴影收/投默认开,三角面拓扑)
pub fn Mesh::new(geometry : BufferGeometry, material : Material) -> Object3D {
  let o = Object3D::new()
  o.mesh = Some({
    geometry,
    material,
    cast_shadow: true,
    receive_shadow: true,
    topology: 0,
  })
  o
}
