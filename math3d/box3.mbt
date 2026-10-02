// three.js Box3 迁移:轴对齐包围盒,不可变风格。
// 未迁:setFromBufferAttribute/setFromObject/expandByObject(依赖
// BufferAttribute/Object3D,属 core 层)、intersectsTriangle(依赖
// Triangle,待其迁移后补)。

///| 轴对齐包围盒(min ≤ max;空盒 min=+∞、max=-∞)
pub(all) struct Box3 {
  min : Vector3
  max : Vector3
} derive(Debug)

pub extend Box3 with Debug::{to_repr}

///| 构造
pub fn Box3::new(min : Vector3, max : Vector3) -> Box3 {
  { min, max }
}

///| 空盒(min=+∞、max=-∞;three.js 构造默认)
pub fn Box3::empty() -> Box3 {
  {
    min: Vector3::new(1.0 / 0.0, 1.0 / 0.0, 1.0 / 0.0),
    max: Vector3::new(-1.0 / 0.0, -1.0 / 0.0, -1.0 / 0.0),
  }
}

///| 置为空盒(three.js makeEmpty;不可变风格下等价 Box3::empty)
pub fn Box3::make_empty() -> Box3 {
  Box3::empty()
}

///| 是否空盒(任一轴 max < min 即空;比体积判空更稳)
pub fn Box3::is_empty(self : Box3) -> Bool {
  self.max.x < self.min.x ||
  self.max.y < self.min.y ||
  self.max.z < self.min.z
}

///| 包住一组点(three.js setFromPoints)
pub fn Box3::set_from_points(points : Array[Vector3]) -> Box3 {
  let mut b = Box3::empty()
  for i in 0..<points.length() {
    b = b.expand_by_point(points[i])
  }
  b
}

///| 包住扁平位置数组(步长 3;尾部不足 3 个的余量忽略)
pub fn Box3::set_from_array(array : Array[Double]) -> Box3 {
  let mut b = Box3::empty()
  let mut i = 0
  while i + 2 < array.length() {
    b = b.expand_by_point(Vector3::new(array[i], array[i + 1], array[i + 2]))
    i += 3
  }
  b
}

///| 以中心与尺寸构造(min=center-size/2、max=center+size/2)
pub fn Box3::set_from_center_and_size(
  center : Vector3,
  size : Vector3,
) -> Box3 {
  let half_size = size.multiply_scalar(0.5)
  { min: center.sub(half_size), max: center.add(half_size) }
}

///| 中心点(空盒返回零向量)
pub fn Box3::get_center(self : Box3) -> Vector3 {
  if self.is_empty() {
    return Vector3::zero()
  }
  self.min.add(self.max).multiply_scalar(0.5)
}

///| 尺寸(空盒返回零向量)
pub fn Box3::get_size(self : Box3) -> Vector3 {
  if self.is_empty() {
    return Vector3::zero()
  }
  self.max.sub(self.min)
}

///| 扩展以包含一点(min/max 逐分量取小/取大)
pub fn Box3::expand_by_point(self : Box3, point : Vector3) -> Box3 {
  { min: self.min.min(point), max: self.max.max(point) }
}

///| 逐轴向外扩 v(宽各加 2*v.x,余类推)
pub fn Box3::expand_by_vector(self : Box3, vector : Vector3) -> Box3 {
  { min: self.min.sub(vector), max: self.max.add(vector) }
}

///| 各轴向外扩标量 s(负值收缩)
pub fn Box3::expand_by_scalar(self : Box3, scalar : Double) -> Box3 {
  {
    min: Vector3::new(
      self.min.x + -scalar,
      self.min.y + -scalar,
      self.min.z + -scalar,
    ),
    max: Vector3::new(
      self.max.x + scalar,
      self.max.y + scalar,
      self.max.z + scalar,
    ),
  }
}

///| 是否包含点(含边界)
pub fn Box3::contains_point(self : Box3, point : Vector3) -> Bool {
  point.x >= self.min.x &&
  point.x <= self.max.x &&
  point.y >= self.min.y &&
  point.y <= self.max.y &&
  point.z >= self.min.z &&
  point.z <= self.max.z
}

///| 是否完整包含另一盒(相等也返回 true)
pub fn Box3::contains_box(self : Box3, box : Box3) -> Bool {
  self.min.x <= box.min.x &&
  box.max.x <= self.max.x &&
  self.min.y <= box.min.y &&
  box.max.y <= self.max.y &&
  self.min.z <= box.min.z &&
  box.max.z <= self.max.z
}

///| 点在盒上的比例坐标(各轴 (p-min)/(max-min);零尺寸轴除零,
///| three.js getParameter 同样不设防)
pub fn Box3::get_parameter(self : Box3, point : Vector3) -> Vector3 {
  Vector3::new(
    (point.x - self.min.x) / (self.max.x - self.min.x),
    (point.y - self.min.y) / (self.max.y - self.min.y),
    (point.z - self.min.z) / (self.max.z - self.min.z),
  )
}

///| 与另一盒相交测试(六分割面排除;接触算相交)
pub fn Box3::intersects_box(self : Box3, box : Box3) -> Bool {
  box.max.x >= self.min.x &&
  box.min.x <= self.max.x &&
  box.max.y >= self.min.y &&
  box.min.y <= self.max.y &&
  box.max.z >= self.min.z &&
  box.min.z <= self.max.z
}

///| 与包围球相交测试(取盒上离球心最近的点判断距离)
pub fn Box3::intersects_sphere(self : Box3, sphere : Sphere) -> Bool {
  let closest = self.clamp_point(sphere.center)
  closest.distance_to_squared(sphere.center) <=
  (sphere.radius * sphere.radius)
}

///| 与平面相交测试(法线各轴按符号选 min/max 端点求点积区间,
///| 区间跨越 -constant 则相交,three.js 同式)
pub fn Box3::intersects_plane(self : Box3, plane : Plane) -> Bool {
  let n = plane.normal
  let mut min = 0.0
  let mut max = 0.0
  if n.x > 0.0 {
    min = n.x * self.min.x
    max = n.x * self.max.x
  } else {
    min = n.x * self.max.x
    max = n.x * self.min.x
  }
  if n.y > 0.0 {
    min = min + n.y * self.min.y
    max = max + n.y * self.max.y
  } else {
    min = min + n.y * self.max.y
    max = max + n.y * self.min.y
  }
  if n.z > 0.0 {
    min = min + n.z * self.min.z
    max = max + n.z * self.max.z
  } else {
    min = min + n.z * self.max.z
    max = max + n.z * self.min.z
  }
  min <= -plane.constant && max >= -plane.constant
}

///| 把点夹进盒内(逐分量 Math.max(min, Math.min(max, x)))
pub fn Box3::clamp_point(self : Box3, point : Vector3) -> Vector3 {
  Vector3::new(
    max_double(self.min.x, min_double(self.max.x, point.x)),
    max_double(self.min.y, min_double(self.max.y, point.y)),
    max_double(self.min.z, min_double(self.max.z, point.z)),
  )
}

///| 盒边到点的欧氏距离(点在盒内为 0)
pub fn Box3::distance_to_point(self : Box3, point : Vector3) -> Double {
  self.clamp_point(point).distance_to(point)
}

///| 包住本盒的最小包围球(空盒返回空球;半径 = 对角线一半)
pub fn Box3::get_bounding_sphere(self : Box3) -> Sphere {
  if self.is_empty() {
    return Sphere::empty()
  }
  Sphere::new(self.get_center(), self.get_size().length() * 0.5)
}

///| 与另一盒求交(无重叠则置为完全空盒,three.js 同式)
pub fn Box3::intersect(self : Box3, box : Box3) -> Box3 {
  let r : Box3 = { min: self.min.max(box.min), max: self.max.min(box.max) }
  if r.is_empty() {
    Box3::empty()
  } else {
    r
  }
}

///| 与另一盒求并
pub fn Box3::union(self : Box3, box : Box3) -> Box3 {
  { min: self.min.min(box.min), max: self.max.max(box.max) }
}

///| 施加 4x4 变换(变换 8 个角点后重取包围盒;空盒仍为空,
///| three.js applyMatrix4 同式)
pub fn Box3::apply_matrix4(self : Box3, matrix : Matrix4) -> Box3 {
  if self.is_empty() {
    return self
  }
  let mn = self.min
  let mx = self.max
  let points : Array[Vector3] = [
    Vector3::new(mn.x, mn.y, mn.z), // 000
    Vector3::new(mn.x, mn.y, mx.z), // 001
    Vector3::new(mn.x, mx.y, mn.z), // 010
    Vector3::new(mn.x, mx.y, mx.z), // 011
    Vector3::new(mx.x, mn.y, mn.z), // 100
    Vector3::new(mx.x, mn.y, mx.z), // 101
    Vector3::new(mx.x, mx.y, mn.z), // 110
    Vector3::new(mx.x, mx.y, mx.z), // 111
  ]
  for i in 0..<8 {
    points[i] = matrix.apply_point(points[i])
  }
  Box3::set_from_points(points)
}

///| 平移
pub fn Box3::translate(self : Box3, offset : Vector3) -> Box3 {
  { min: self.min.add(offset), max: self.max.add(offset) }
}

///| 分量相等(精确)
pub fn Box3::equals(self : Box3, other : Box3) -> Bool {
  self.min.equals(other.min) && self.max.equals(other.max)
}
