// three.js Vector4 迁移:不可变风格,运算返回新值。

///| 四维向量
pub(all) struct Vector4 {
  x : Double
  y : Double
  z : Double
  w : Double
} derive(Debug)

pub extend Vector4 with Debug::{to_repr}


///| 构造
pub fn Vector4::new(
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Vector4 {
  { x, y, z, w }
}

///| 零向量
pub fn Vector4::zero() -> Vector4 {
  { x: 0.0, y: 0.0, z: 0.0, w: 0.0 }
}

///| 分量逐项相加
pub fn Vector4::add(self : Vector4, other : Vector4) -> Vector4 {
  {
    x: self.x + other.x,
    y: self.y + other.y,
    z: self.z + other.z,
    w: self.w + other.w,
  }
}

///| 分量逐项相减
pub fn Vector4::sub(self : Vector4, other : Vector4) -> Vector4 {
  {
    x: self.x - other.x,
    y: self.y - other.y,
    z: self.z - other.z,
    w: self.w - other.w,
  }
}

///| 数乘
pub fn Vector4::multiply_scalar(self : Vector4, s : Double) -> Vector4 {
  { x: self.x * s, y: self.y * s, z: self.z * s, w: self.w * s }
}

///| 数除(乘 1/s,除零得 ±Infinity/NaN,three.js divideScalar 同式)
pub fn Vector4::divide_scalar(self : Vector4, s : Double) -> Vector4 {
  self.multiply_scalar(1.0 / s)
}

///| 点积
pub fn Vector4::dot(self : Vector4, other : Vector4) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z +
  self.w * other.w
}

///| 范数平方
pub fn Vector4::length2(self : Vector4) -> Double {
  self.dot(self)
}

///| 范数
pub fn Vector4::length(self : Vector4) -> Double {
  self.length2().sqrt()
}

///| 单位化(零向量返回零;乘 1/(len||1),three.js normalize 同式)
pub fn Vector4::normalize(self : Vector4) -> Vector4 {
  let len = self.length()
  self.divide_scalar(if len == 0.0 { 1.0 } else { len })
}

///| 线性插值
pub fn Vector4::lerp(self : Vector4, other : Vector4, alpha : Double) -> Vector4 {
  {
    x: self.x + (other.x - self.x) * alpha,
    y: self.y + (other.y - self.y) * alpha,
    z: self.z + (other.z - self.z) * alpha,
    w: self.w + (other.w - self.w) * alpha,
  }
}

///| 分量相等(精确)
pub fn Vector4::equals(self : Vector4, other : Vector4) -> Bool {
  self.x == other.x && self.y == other.y && self.z == other.z &&
  self.w == other.w
}
