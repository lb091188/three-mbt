// three.js PerspectiveCamera 迁移:fov 度数制,投影与视图矩阵。

///| 透视相机
pub(all) struct PerspectiveCamera {
  /// 相机自身节点(变换挂这里)
  obj : Object3D
  /// 垂直视场角(度)
  mut fov : Double
  /// 宽高比
  mut aspect : Double
  mut near : Double
  mut far : Double
  /// 投影矩阵(参数变化后调 update_projection_matrix 重建)
  mut projection_matrix : @math3d.Matrix4
  /// 视图矩阵的逆(camera 世界矩阵)
  mut matrix_world_inverse : @math3d.Matrix4
}

///| 构造并立即计算投影矩阵
pub fn PerspectiveCamera::new(
  fov : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> PerspectiveCamera {
  let c : PerspectiveCamera = {
    obj: Object3D::new(),
    fov,
    aspect,
    near,
    far,
    projection_matrix: @math3d.Matrix4::identity(),
    matrix_world_inverse: @math3d.Matrix4::identity(),
  }
  c.update_projection_matrix()
  c
}

///| 重建投影矩阵(fov/aspect/near/far 变化后调用)
pub fn PerspectiveCamera::update_projection_matrix(
  self : PerspectiveCamera,
) -> Unit {
  let fov_rad = self.fov * 3.141592653589793 / 180.0
  self.projection_matrix = @math3d.Matrix4::make_perspective(
    fov_rad,
    self.aspect,
    self.near,
    self.far,
  )
}

///| 相机视图矩阵(matrix_world 的逆;渲染前调 update_matrix_world 后取)
pub fn PerspectiveCamera::view_matrix(
  self : PerspectiveCamera,
) -> @math3d.Matrix4 {
  self.obj.update_matrix_world(false)
  self.matrix_world_inverse = self.obj.matrix_world.invert()
  self.matrix_world_inverse
}

///| 相机朝向:把相机摆到 eye 看向 target(three.js lookAt 便捷)
pub fn PerspectiveCamera::look_at(
  self : PerspectiveCamera,
  eye : @math3d.Vector3,
  target : @math3d.Vector3,
) -> Unit {
  // make_look_at 产出视图矩阵(世界→相机),其逆的旋转部分即相机朝向
  let view = @math3d.Matrix4::make_look_at(
    eye,
    target,
    @math3d.Vector3::unit_y(),
  )
  self.obj.position = eye
  self.obj.rotation = view.invert().to_quaternion()
  self.obj.update_matrix()
}
