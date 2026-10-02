// three.js Vector3 迁移:不可变风格,运算返回新值。

///| 三维向量
pub(all) struct Vector3 {
  x : Double
  y : Double
  z : Double
} derive(Debug)

pub extend Vector3 with Debug::{to_repr}


///| 构造
pub fn Vector3::new(x : Double, y : Double, z : Double) -> Vector3 {
  { x, y, z }
}

///| 零向量
pub fn Vector3::zero() -> Vector3 {
  { x: 0.0, y: 0.0, z: 0.0 }
}

///| 单位基向量
pub fn Vector3::unit_x() -> Vector3 {
  { x: 1.0, y: 0.0, z: 0.0 }
}

///| Y 轴单位基向量
pub fn Vector3::unit_y() -> Vector3 {
  { x: 0.0, y: 1.0, z: 0.0 }
}

///| Z 轴单位基向量
pub fn Vector3::unit_z() -> Vector3 {
  { x: 0.0, y: 0.0, z: 1.0 }
}

///| 分量逐项相加
pub fn Vector3::add(self : Vector3, other : Vector3) -> Vector3 {
  { x: self.x + other.x, y: self.y + other.y, z: self.z + other.z }
}

///| 分量逐项相减
pub fn Vector3::sub(self : Vector3, other : Vector3) -> Vector3 {
  { x: self.x - other.x, y: self.y - other.y, z: self.z - other.z }
}

///| 数乘
pub fn Vector3::multiply_scalar(self : Vector3, s : Double) -> Vector3 {
  { x: self.x * s, y: self.y * s, z: self.z * s }
}

///| 数除(乘 1/s,除零得 ±Infinity/NaN,three.js divideScalar 同式)
pub fn Vector3::divide_scalar(self : Vector3, s : Double) -> Vector3 {
  self.multiply_scalar(1.0 / s)
}

///| 点积
pub fn Vector3::dot(self : Vector3, other : Vector3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///| 叉积(右手系)
pub fn Vector3::cross(self : Vector3, other : Vector3) -> Vector3 {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///| 范数平方
pub fn Vector3::length2(self : Vector3) -> Double {
  self.dot(self)
}

///| 范数
pub fn Vector3::length(self : Vector3) -> Double {
  self.length2().sqrt()
}

///| 单位化(零向量返回零;乘 1/(len||1),three.js normalize 同式)
pub fn Vector3::normalize(self : Vector3) -> Vector3 {
  let len = self.length()
  self.divide_scalar(if len == 0.0 { 1.0 } else { len })
}

///| 取反
pub fn Vector3::negate(self : Vector3) -> Vector3 {
  { x: -self.x, y: -self.y, z: -self.z }
}

///| 线性插值
pub fn Vector3::lerp(
  self : Vector3,
  other : Vector3,
  alpha : Double,
) -> Vector3 {
  {
    x: self.x + (other.x - self.x) * alpha,
    y: self.y + (other.y - self.y) * alpha,
    z: self.z + (other.z - self.z) * alpha,
  }
}

///| 距离平方
pub fn Vector3::distance_to_squared(
  self : Vector3,
  other : Vector3,
) -> Double {
  let dx = self.x - other.x
  let dy = self.y - other.y
  let dz = self.z - other.z
  dx * dx + dy * dy + dz * dz
}

///| 距离
pub fn Vector3::distance_to(self : Vector3, other : Vector3) -> Double {
  self.distance_to_squared(other).sqrt()
}

///| 分量相等(精确)
pub fn Vector3::equals(self : Vector3, other : Vector3) -> Bool {
  self.x == other.x && self.y == other.y && self.z == other.z
}

// Math.min 语义:NaN 传播;±0 相等时取 -0(1/x<0 判 -0)
fn min_double(a : Double, b : Double) -> Double {
  if a != a {
    return a
  }
  if b != b {
    return b
  }
  if a == b {
    if a == 0.0 && (1.0 / a < 0.0 || 1.0 / b < 0.0) {
      return -0.0
    }
    return a
  }
  if a < b {
    a
  } else {
    b
  }
}

// Math.max 语义:NaN 传播;±0 相等时取 +0(两者皆 -0 才为 -0)
fn max_double(a : Double, b : Double) -> Double {
  if a != a {
    return a
  }
  if b != b {
    return b
  }
  if a == b {
    if a == 0.0 && !(1.0 / a < 0.0 && 1.0 / b < 0.0) {
      return 0.0
    }
    return a
  }
  if a > b {
    a
  } else {
    b
  }
}

///| 按分量取较小(Math.min 语义:NaN 传播、±0 取 -0)
pub fn Vector3::min(self : Vector3, other : Vector3) -> Vector3 {
  {
    x: min_double(self.x, other.x),
    y: min_double(self.y, other.y),
    z: min_double(self.z, other.z),
  }
}

///| 按分量取较大(Math.max 语义:NaN 传播、±0 取 +0)
pub fn Vector3::max(self : Vector3, other : Vector3) -> Vector3 {
  {
    x: max_double(self.x, other.x),
    y: max_double(self.y, other.y),
    z: max_double(self.z, other.z),
  }
}
