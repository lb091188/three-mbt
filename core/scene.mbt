// three.js Scene 迁移:场景根 + 背景色。

///| 场景
pub(all) struct Scene {
  /// 场景根节点(往这上面 add)
  root : Object3D
  /// 背景色(None=渲染器默认清屏色)
  mut background : @math3d.Color?
}

///| 构造空场景
pub fn Scene::new() -> Scene {
  { root: Object3D::new(), background: None }
}

///| 挂子节点到场景
pub fn Scene::add(self : Scene, child : Object3D) -> Unit {
  self.root.add(child)
}

///| 更新整棵场景的世界矩阵(渲染前调用)
pub fn Scene::update_matrix_world(self : Scene) -> Unit {
  self.root.update_matrix_world(false)
}
