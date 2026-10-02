// three.js Object3D 迁移:场景图节点(变换层级)。
// local 矩阵按 three.js 约定 compose 为 T * R * S(列主序作用于列向量)。

// 节点唯一 id 发号器(同一性判定与调试用)
let next_node_id : Ref[UInt64] = Ref(0UL)

///| 场景图节点:变换、层级与可见性
pub(all) struct Object3D {
  /// 唯一 id(同一性判定)
  id : UInt64
  /// 平移(局部)
  mut position : @math3d.Vector3
  /// 旋转(四元数,局部)
  mut rotation : @math3d.Quaternion
  /// 缩放(局部)
  mut scale : @math3d.Vector3
  /// 局部矩阵(由 update_matrix 从 position/rotation/scale 重建)
  mut matrix : @math3d.Matrix4
  /// 世界矩阵(由 update_matrix_world 沿层级合成)
  mut matrix_world : @math3d.Matrix4
  mut visible : Bool
  mut name : String
  /// 子节点(数组内容可变;父子互斥由 add/remove 维护)
  children : Array[Object3D]
  mut parent : Object3D?
}

///| 构造(单位变换)
pub fn Object3D::new() -> Object3D {
  next_node_id.val = next_node_id.val + 1UL
  {
    id: next_node_id.val,
    position: @math3d.Vector3::zero(),
    rotation: @math3d.Quaternion::identity(),
    scale: @math3d.Vector3::new(1.0, 1.0, 1.0),
    matrix: @math3d.Matrix4::identity(),
    matrix_world: @math3d.Matrix4::identity(),
    visible: true,
    name: "",
    children: [],
    parent: None,
  }
}

///| 从当前 position/rotation/scale 重建局部矩阵(T*R*S)
pub fn Object3D::update_matrix(self : Object3D) -> Unit {
  self.matrix = @math3d.Matrix4::make_translation(
    self.position.x,
    self.position.y,
    self.position.z,
  ).multiply(self.rotation.to_matrix4()).multiply(
    @math3d.Matrix4::make_scale(self.scale.x, self.scale.y, self.scale.z),
  )
}

///| 沿层级合成世界矩阵(父先于子;force 语义与 three.js 一致:
/// force=true 时无条件重算,否则 matrix_needs_update 细粒度标记 W3 再引入,
/// 首版统一重算,正确性优先)
pub fn Object3D::update_matrix_world(self : Object3D, force : Bool) -> Unit {
  ignore(force)
  self.update_matrix()
  match self.parent {
    Some(p) => self.matrix_world = p.matrix_world.multiply(self.matrix)
    None => self.matrix_world = self.matrix
  }
  for child in self.children {
    child.update_matrix_world(true)
  }
}

///| 挂子节点(若已在其他父下先摘除)
pub fn Object3D::add(self : Object3D, child : Object3D) -> Unit {
  match child.parent {
    Some(p) => if p.id == self.id { return }
    None => ()
  }
  match child.parent {
    Some(p) => p.remove(child)
    None => ()
  }
  child.parent = Some(self)
  self.children.push(child)
}

///| 摘除子节点
pub fn Object3D::remove(self : Object3D, child : Object3D) -> Unit {
  match child.parent {
    Some(p) if p.id == self.id => {
      child.parent = None
      let mut i = 0
      while i < self.children.length() {
        if self.children[i].id == child.id {
          let _ = self.children.remove(i)
          ()
        } else {
          i = i + 1
        }
      }
    }
    _ => ()
  }
}

///| 世界坐标(需已 update_matrix_world)
pub fn Object3D::world_position(self : Object3D) -> @math3d.Vector3 {
  self.matrix_world.apply_point(@math3d.Vector3::zero())
}

///| 深度优先遍历(含自身;callback 返回 false 跳过子树)
pub fn Object3D::traverse(
  self : Object3D,
  visit : (Object3D) -> Bool,
) -> Unit {
  if visit(self) {
    for child in self.children {
      child.traverse(visit)
    }
  }
}
