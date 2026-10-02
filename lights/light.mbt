// three.js Light 基类迁移:MoonBit 无继承,color/intensity 公共字段平铺进各光源,
// 本文件只承载各光源共享的 Object3D 拷贝工具。
// three.js Object3D.copy 会拷 position/rotation/scale/matrix/matrixWorld/visible/name,
// 不动层级;这里在 core/Object3D 已有字段上对齐该拷贝集。

///| 就地拷贝节点变换与状态(不拷层级;对齐 three.js Object3D.copy)
fn copy_object3d_into(target : @core.Object3D, source : @core.Object3D) -> Unit {
  target.position = source.position
  target.rotation = source.rotation
  target.scale = source.scale
  target.matrix = source.matrix
  target.matrix_world = source.matrix_world
  target.visible = source.visible
  target.name = source.name
}

///| 新建节点并拷入变换与状态(对齐 three.js Object3D.clone(recursive=false):
///| 拷自身字段、不带子节点不带父)
fn copy_object3d(source : @core.Object3D) -> @core.Object3D {
  let o = @core.Object3D::new()
  copy_object3d_into(o, source)
  o
}
