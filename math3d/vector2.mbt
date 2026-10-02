// three.js Vector2 迁移:不可变风格,运算返回新值;
// 热路径可变变体按需在 core 层补充。

///| 二维向量
pub(all) struct Vector2 {
  x : Double
  y : Double
} derive(Debug)

pub extend Vector2 with Debug::{to_repr}


///| 构造
pub fn Vector2::new(x : Double, y : Double) -> Vector2 {
  { x, y }
}

///| 零向量
pub fn Vector2::zero() -> Vector2 {
  { x: 0.0, y: 0.0 }
}

///| 分量逐项相加
pub fn Vector2::add(self : Vector2, other : Vector2) -> Vector2 {
  { x: self.x + other.x, y: self.y + other.y }
}

///| 分量逐项相减
pub fn Vector2::sub(self : Vector2, other : Vector2) -> Vector2 {
  { x: self.x - other.x, y: self.y - other.y }
}

///| 数乘
pub fn Vector2::multiply_scalar(self : Vector2, s : Double) -> Vector2 {
  { x: self.x * s, y: self.y * s }
}

///| 数除(乘 1/s,除零得 ±Infinity/NaN,three.js divideScalar 同式)
pub fn Vector2::divide_scalar(self : Vector2, s : Double) -> Vector2 {
  self.multiply_scalar(1.0 / s)
}

///| 点积
pub fn Vector2::dot(self : Vector2, other : Vector2) -> Double {
  self.x * other.x + self.y * other.y
}

///| 范数平方
pub fn Vector2::length2(self : Vector2) -> Double {
  self.dot(self)
}

///| 范数
pub fn Vector2::length(self : Vector2) -> Double {
  self.length2().sqrt()
}

///| 单位化(零向量返回零;乘 1/(len||1),three.js normalize 同式)
pub fn Vector2::normalize(self : Vector2) -> Vector2 {
  let len = self.length()
  self.divide_scalar(if len == 0.0 { 1.0 } else { len })
}

///| 取反
pub fn Vector2::negate(self : Vector2) -> Vector2 {
  { x: -self.x, y: -self.y }
}

///| 线性插值
pub fn Vector2::lerp(self : Vector2, other : Vector2, alpha : Double) -> Vector2 {
  {
    x: self.x + (other.x - self.x) * alpha,
    y: self.y + (other.y - self.y) * alpha,
  }
}

///| 距离平方
pub fn Vector2::distance_to_squared(
  self : Vector2,
  other : Vector2,
) -> Double {
  let dx = self.x - other.x
  let dy = self.y - other.y
  dx * dx + dy * dy
}

///| 距离
pub fn Vector2::distance_to(self : Vector2, other : Vector2) -> Double {
  self.distance_to_squared(other).sqrt()
}

///| 分量相等(精确)
pub fn Vector2::equals(self : Vector2, other : Vector2) -> Bool {
  self.x == other.x && self.y == other.y
}
