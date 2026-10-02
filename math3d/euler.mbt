// three.js Euler 迁移:XYZ 旋转序(three.js 默认),角度单位弧度。

///| 欧拉角(XYZ 序)
pub(all) struct Euler {
  x : Double
  y : Double
  z : Double
} derive(Debug)

pub extend Euler with Debug::{to_repr}

///| 构造
pub fn Euler::new(x : Double, y : Double, z : Double) -> Euler {
  { x, y, z }
}

///| 零欧拉角
pub fn Euler::zero() -> Euler {
  { x: 0.0, y: 0.0, z: 0.0 }
}

///| 分量相等(精确)
pub fn Euler::equals(self : Euler, other : Euler) -> Bool {
  self.x == other.x && self.y == other.y && self.z == other.z
}
