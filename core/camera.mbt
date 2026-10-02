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

///| 相机视图矩阵(matrix_world 的逆;scale≠1 时按 glTF 一致语义剔除缩放,
///| three.js Camera.updateMatrixWorld 同式;渲染前调 update_matrix_world 后取)
pub fn PerspectiveCamera::view_matrix(
  self : PerspectiveCamera,
) -> @math3d.Matrix4 {
  self.obj.update_matrix_world(false)
  let (pos, quat, scale) = self.obj.matrix_world.decompose()
  self.matrix_world_inverse = if scale.x == 1.0 &&
    scale.y == 1.0 &&
    scale.z == 1.0 {
    self.obj.matrix_world.invert()
  } else {
    // compose(pos, quat, (1,1,1)) 再求逆 = T*R 的逆
    @math3d.Matrix4::make_translation(
        pos.x,
        pos.y,
        pos.z,
      ).multiply(quat.to_matrix4()).invert()
  }
  self.matrix_world_inverse
}

///| 相机朝向:把相机摆到 eye 看向 target(eye/target 按世界坐标,相机
///| 最终世界位置=eye、世界朝向指向 target;挂在带变换的父节点下时旋转
///| 与位置都剔除父变换,three.js Object3D.lookAt 相机分支同语义;
///| eye==target、up 与视线共线等边界由 make_look_at 内的 three.js 同式
///| 回退分支处理)
pub fn PerspectiveCamera::look_at(
  self : PerspectiveCamera,
  eye : @math3d.Vector3,
  target : @math3d.Vector3,
) -> Unit {
  // 先沿父链刷新世界矩阵(three.js updateWorldMatrix(true,false))
  self.obj.update_world_matrix(true, false)
  let m1 = @math3d.Matrix4::make_look_at(
    eye,
    target,
    @math3d.Vector3::unit_y(),
  )
  let mut q = m1.to_quaternion()
  let mut pos = eye
  match self.obj.parent {
    Some(p) => {
      // 世界姿态转局部:旋转左乘父世界旋转的逆,位置经父世界矩阵的逆变换
      let (_, pq, _) = p.matrix_world.decompose()
      q = pq.invert().multiply(q)
      pos = p.matrix_world.invert().apply_point(eye)
    }
    None => ()
  }
  self.obj.position = pos
  self.obj.rotation = q
  self.obj.update_matrix()
}

///| 正交相机:物体渲染尺寸与视距无关,适合渲染 2D 场景与 UI 元素
pub(all) struct OrthographicCamera {
  /// 相机自身节点(变换挂这里)
  obj : Object3D
  /// 视锥左平面
  mut left : Double
  /// 视锥右平面
  mut right : Double
  /// 视锥上平面
  mut top : Double
  /// 视锥下平面
  mut bottom : Double
  /// 近裁剪面(正交相机允许取 0,与透视相机不同)
  mut near : Double
  /// 远裁剪面(须大于 near)
  mut far : Double
  /// 投影矩阵(参数变化后调 update_projection_matrix 重建)
  mut projection_matrix : @math3d.Matrix4
  /// 视图矩阵的逆(camera 世界矩阵)
  mut matrix_world_inverse : @math3d.Matrix4
}

///| 构造并立即计算投影矩阵(three.js 参数序 left/right/top/bottom/near/far,
///| 其默认值 -1/1/1/-1/0.1/2000 由调用方显式传入)
pub fn OrthographicCamera::new(
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
  near : Double,
  far : Double,
) -> OrthographicCamera {
  let c : OrthographicCamera = {
    obj: Object3D::new(),
    left,
    right,
    top,
    bottom,
    near,
    far,
    projection_matrix: @math3d.Matrix4::identity(),
    matrix_world_inverse: @math3d.Matrix4::identity(),
  }
  c.update_projection_matrix()
  c
}

///| 重建投影矩阵(视锥参数变化后调用);中心-半宽式与 three.js
///| updateProjectionMatrix 一致(zoom=1、view=null 时还原原始边界)
pub fn OrthographicCamera::update_projection_matrix(
  self : OrthographicCamera,
) -> Unit {
  // three.js:dx=(r-l)/(2*zoom)、dy=(t-b)/(2*zoom),zoom 恒 1 折叠为 /2
  let dx = (self.right - self.left) / 2.0
  let dy = (self.top - self.bottom) / 2.0
  let cx = (self.right + self.left) / 2.0
  let cy = (self.top + self.bottom) / 2.0
  // view 偏移分支(setViewOffset)未迁移,等价于 three.js view=null 路径
  self.projection_matrix = @math3d.Matrix4::make_orthographic(
    cx - dx,
    cx + dx,
    cy + dy,
    cy - dy,
    self.near,
    self.far,
  )
}
