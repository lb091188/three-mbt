// three.js Mesh 迁移:Object3D + geometry + material。

///| 渲染组件(挂在 Object3D.mesh 上)
pub(all) struct Mesh {
  geometry : BufferGeometry
  material : Material
}

///| 构造网格节点(geometry+material 挂到新 Object3D)
pub fn Mesh::new(
  geometry : BufferGeometry,
  material : Material,
) -> Object3D {
  let o = Object3D::new()
  o.mesh = Some({ geometry, material, })
  o
}
