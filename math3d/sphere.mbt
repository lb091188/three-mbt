// three.js Sphere 迁移:解析球(中心+半径),不可变风格。
// 半径为负表示空球;半径 0 只含中心点,不算空。

///| 解析球(center 为球心,radius 为半径;radius<0 为空球)
pub(all) struct Sphere {
  center : Vector3
  radius : Double
} derive(Debug)

pub extend Sphere with Debug::{to_repr}

///| 构造
pub fn Sphere::new(center : Vector3, radius : Double) -> Sphere {
  { center, radius }
}

///| 空球(center=(0,0,0)、radius=-1;three.js 构造默认)
pub fn Sphere::empty() -> Sphere {
  { center: Vector3::zero(), radius: -1.0 }
}

///| 置为空球(three.js makeEmpty;不可变风格下等价 Sphere::empty)
pub fn Sphere::make_empty() -> Sphere {
  Sphere::empty()
}

///| 是否空球(radius<0;radius=0 只含中心点,不算空)
pub fn Sphere::is_empty(self : Sphere) -> Bool {
  self.radius < 0.0
}

///| 包住一组点的最小球(以各点包围盒中心为球心,取最远点定半径;
///| three.js setFromPoints 不带中心参数的分支)
pub fn Sphere::set_from_points(points : Array[Vector3]) -> Sphere {
  let center = Box3::set_from_points(points).get_center()
  Sphere::set_from_points_centered(points, center)
}

///| 包住一组点的最小球(显式指定球心,three.js setFromPoints 带
///| optionalCenter 的分支)
pub fn Sphere::set_from_points_centered(
  points : Array[Vector3],
  center : Vector3,
) -> Sphere {
  let mut max_radius_sq = 0.0
  for i in 0..<points.length() {
    max_radius_sq = max_double(
      max_radius_sq,
      center.distance_to_squared(points[i]),
    )
  }
  { center, radius: max_radius_sq.sqrt() }
}

///| 是否包含点(含球面)
pub fn Sphere::contains_point(self : Sphere, point : Vector3) -> Bool {
  point.distance_to_squared(self.center) <=
  (self.radius * self.radius)
}

///| 到点的距离(点在球内为负)
pub fn Sphere::distance_to_point(self : Sphere, point : Vector3) -> Double {
  point.distance_to(self.center) - self.radius
}

///| 与另一球相交测试(半径和判据)
pub fn Sphere::intersects_sphere(self : Sphere, sphere : Sphere) -> Bool {
  let radius_sum = self.radius + sphere.radius
  sphere.center.distance_to_squared(self.center) <=
  (radius_sum * radius_sum)
}

///| 与包围盒相交测试(委托 Box3::intersects_sphere)
pub fn Sphere::intersects_box(self : Sphere, box : Box3) -> Bool {
  box.intersects_sphere(self)
}

///| 与平面相交测试(|球心带符号距离| ≤ radius)
pub fn Sphere::intersects_plane(self : Sphere, plane : Plane) -> Bool {
  plane.distance_to_point(self.center).abs() <= self.radius
}

///| 把点夹进球内(球外的点夹到沿方向的球面点;球内不动)
pub fn Sphere::clamp_point(self : Sphere, point : Vector3) -> Vector3 {
  let delta_length_sq = self.center.distance_to_squared(point)
  if delta_length_sq > self.radius * self.radius {
    return point.sub(self.center).normalize().multiply_scalar(
        self.radius,
      )
      .add(self.center)
  }
  point
}

///| 包住本球的最小包围盒(空球返回空盒;以中心为心各轴 ±radius)
pub fn Sphere::get_bounding_box(self : Sphere) -> Box3 {
  if self.is_empty() {
    return Box3::empty()
  }
  Box3::new(self.center, self.center).expand_by_scalar(self.radius)
}

///| 施加 4x4 变换(球心按点变换,半径乘矩阵最大缩放)
pub fn Sphere::apply_matrix4(self : Sphere, matrix : Matrix4) -> Sphere {
  {
    center: matrix.apply_point(self.center),
    radius: self.radius * matrix.max_scale_on_axis(),
  }
}

///| 平移球心
pub fn Sphere::translate(self : Sphere, offset : Vector3) -> Sphere {
  { center: self.center.add(offset), radius: self.radius }
}

///| 扩展以包含一点(空球收入该点为球心、半径 0;否则仅当点在球外
///| 时沿方向扩半径的一半,three.js expandByPoint 同式)
pub fn Sphere::expand_by_point(self : Sphere, point : Vector3) -> Sphere {
  if self.is_empty() {
    return { center: point, radius: 0.0 }
  }
  let v = point.sub(self.center)
  let length_sq = v.length2()
  if length_sq > self.radius * self.radius {
    // 计算能同时包住原球与该点的最小球
    let length = length_sq.sqrt()
    let delta = (length - self.radius) * 0.5
    return {
      center: vec3_add_scaled(self.center, v, delta / length),
      radius: self.radius + delta,
    }
  }
  self
}

///| 扩展以同时包住另一球(同心理论最大半径;一般情形在对方球心
///| 连线方向取两个极端点逐个收入,three.js union 同式)
pub fn Sphere::union(self : Sphere, sphere : Sphere) -> Sphere {
  if sphere.is_empty() {
    return self
  }
  if self.is_empty() {
    return sphere
  }
  if self.center.equals(sphere.center) {
    return { center: self.center, radius: max_double(self.radius, sphere.radius) }
  }
  // 对方球心方向上单位向量按其半径缩放,得到其两端极端点;
  // 先收远端再收近端(three.js union 同序)
  let v2 = sphere.center.sub(self.center).normalize().multiply_scalar(
      sphere.radius,
    )
  let far = sphere.center.add(v2)
  let near = sphere.center.sub(v2)
  self.expand_by_point(far).expand_by_point(near)
}

///| 分量相等(精确)
pub fn Sphere::equals(self : Sphere, other : Sphere) -> Bool {
  self.center.equals(other.center) && self.radius == other.radius
}
