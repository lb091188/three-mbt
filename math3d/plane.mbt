// three.js Plane 迁移:Hessian 法式(normal·x + constant = 0),不可变风格。
// Line3 未单独成类,intersect_line/intersects_line 以线段两端点表示。

///| 平面(Hessian 法式:normal 为单位法线,constant 为原点到平面的有符号距离)
pub(all) struct Plane {
  normal : Vector3
  constant : Double
} derive(Debug)

pub extend Plane with Debug::{to_repr}

///| 构造(normal 应为单位向量)
pub fn Plane::new(normal : Vector3, constant : Double) -> Plane {
  { normal, constant }
}

///| 默认平面 x=0(three.js 构造默认:normal=(1,0,0)、constant=0)
pub fn Plane::default() -> Plane {
  { normal: Vector3::unit_x(), constant: 0.0 }
}

///| 以分量构造(normal=(x,y,z)、constant=w)
pub fn Plane::set_components(
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Plane {
  { normal: Vector3::new(x, y, z), constant: w }
}

///| 由法线与共面点构造(constant = -(point·normal);法线不代为归一化)
pub fn Plane::set_from_normal_and_coplanar_point(
  normal : Vector3,
  point : Vector3,
) -> Plane {
  { normal, constant: -point.dot(normal) }
}

///| 由三个共面点构造(绕序逆时针决定法线方向)
pub fn Plane::set_from_coplanar_points(
  a : Vector3,
  b : Vector3,
  c : Vector3,
) -> Plane {
  let normal = c.sub(b).cross(a.sub(b)).normalize()
  Plane::set_from_normal_and_coplanar_point(normal, a)
}

///| 归一化:法线与常数同除以法线长度(法线为零向量时除零,three.js 同式)
pub fn Plane::normalize(self : Plane) -> Plane {
  let inverse_normal_length = 1.0 / self.normal.length()
  {
    normal: self.normal.multiply_scalar(inverse_normal_length),
    constant: self.constant * inverse_normal_length,
  }
}

///| 取反:法线与常数同时取负
pub fn Plane::negate(self : Plane) -> Plane {
  { normal: self.normal.negate(), constant: -self.constant }
}

///| 点到平面的有符号距离(normal·point + constant)
pub fn Plane::distance_to_point(self : Plane, point : Vector3) -> Double {
  self.normal.dot(point) + self.constant
}

///| 球到平面的有符号距离(球心距离减半径)
pub fn Plane::distance_to_sphere(self : Plane, sphere : Sphere) -> Double {
  self.distance_to_point(sphere.center) - sphere.radius
}

///| 点沿法线方向投影到平面
pub fn Plane::project_point(self : Plane, point : Vector3) -> Vector3 {
  vec3_add_scaled(point, self.normal, -self.distance_to_point(point))
}

///| 与线段求交:返回交点;线段共面返回起点;平行不共面返回 None。
///| clamp_to_line 为 true 时交点越出 [start,end] 区间返回 None
pub fn Plane::intersect_line(
  self : Plane,
  start : Vector3,
  end : Vector3,
  clamp_to_line : Bool,
) -> Vector3? {
  let direction = end.sub(start)
  let denominator = self.normal.dot(direction)
  if denominator == 0.0 {
    // 线段所在直线与平面平行:共面返回起点,否则无交点
    if self.distance_to_point(start) == 0.0 {
      return Some(start)
    }
    return None
  }
  let t = -(start.dot(self.normal) + self.constant) / denominator
  if clamp_to_line && (t < 0.0 || t > 1.0) {
    return None
  }
  Some(vec3_add_scaled(start, direction, t))
}

///| 线段是否穿过平面(两端点严格分居两侧;共面不算)
pub fn Plane::intersects_line(
  self : Plane,
  start : Vector3,
  end : Vector3,
) -> Bool {
  let start_sign = self.distance_to_point(start)
  let end_sign = self.distance_to_point(end)
  (start_sign < 0.0 && end_sign > 0.0) ||
  (end_sign < 0.0 && start_sign > 0.0)
}

///| 与包围盒相交测试(委托 Box3::intersects_plane)
pub fn Plane::intersects_box(self : Plane, box : Box3) -> Bool {
  box.intersects_plane(self)
}

///| 与包围球相交测试(委托 Sphere::intersects_plane)
pub fn Plane::intersects_sphere(self : Plane, sphere : Sphere) -> Bool {
  sphere.intersects_plane(self)
}

///| 原点处法线在平面上的投影点(normal * -constant)
pub fn Plane::coplanar_point(self : Plane) -> Vector3 {
  self.normal.multiply_scalar(-self.constant)
}

///| 施加 4x4 仿射变换(内部计算法线矩阵;需复用时可先以
///| Matrix3::normal_from_matrix4 预计算再调 apply_matrix4_with_normal_matrix)
pub fn Plane::apply_matrix4(self : Plane, matrix : Matrix4) -> Plane {
  let normal_matrix = Matrix3::normal_from_matrix4(matrix)
  self.apply_matrix4_with_normal_matrix(matrix, normal_matrix)
}

///| 施加 4x4 仿射变换并复用预计算的法线矩阵(参照点过 w 归一,
///| 法线过法线矩阵后归一,常数 = -(参照点·法线),three.js 同式)
pub fn Plane::apply_matrix4_with_normal_matrix(
  self : Plane,
  matrix : Matrix4,
  normal_matrix : Matrix3,
) -> Plane {
  let reference_point = matrix.apply_point(self.coplanar_point())
  let normal = normal_matrix.apply(self.normal).normalize()
  { normal, constant: -reference_point.dot(normal) }
}

///| 平移平面(只改常数,法线不变)
pub fn Plane::translate(self : Plane, offset : Vector3) -> Plane {
  { normal: self.normal, constant: self.constant - offset.dot(self.normal) }
}

///| 分量相等(精确)
pub fn Plane::equals(self : Plane, other : Plane) -> Bool {
  self.normal.equals(other.normal) && self.constant == other.constant
}
