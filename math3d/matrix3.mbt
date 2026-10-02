// three.js Matrix3 迁移:3x3 列主序,主要用途是法线矩阵。

///| 列主序 3x3 矩阵(e[col*3 + row])
pub(all) struct Matrix3 {
  e : Array[Double]
} derive(Debug)

pub extend Matrix3 with Debug::{to_repr}

///| 单位矩阵
pub fn Matrix3::identity() -> Matrix3 {
  let e = Array::make(9, 0.0)
  e[0] = 1.0
  e[4] = 1.0
  e[8] = 1.0
  { e, }
}

///| 从 4x4 取左上 3x3
pub fn Matrix3::from_matrix4(m : Matrix4) -> Matrix3 {
  let s = m.e
  let e = Array::make(9, 0.0)
  e[0] = s[0]
  e[1] = s[1]
  e[2] = s[2]
  e[3] = s[4]
  e[4] = s[5]
  e[5] = s[6]
  e[6] = s[8]
  e[7] = s[9]
  e[8] = s[10]
  { e, }
}

///| 法线矩阵:模型视图矩阵逆转置的 3x3(three.js getNormalMatrix 同义)
pub fn Matrix3::normal_from_matrix4(m : Matrix4) -> Matrix3 {
  Matrix3::from_matrix4(m.invert()).transpose()
}

///| 转置
pub fn Matrix3::transpose(self : Matrix3) -> Matrix3 {
  let a = self.e
  let e = Array::make(9, 0.0)
  for col in 0..<3 {
    for row in 0..<3 {
      e[row * 3 + col] = a[col * 3 + row]
    }
  }
  { e, }
}

///| 变换三维向量
pub fn Matrix3::apply(self : Matrix3, v : Vector3) -> Vector3 {
  let m = self.e
  {
    x: m[0] * v.x + m[3] * v.y + m[6] * v.z,
    y: m[1] * v.x + m[4] * v.y + m[7] * v.z,
    z: m[2] * v.x + m[5] * v.y + m[8] * v.z,
  }
}

///| 相等(精确)
pub fn Matrix3::equals(self : Matrix3, other : Matrix3) -> Bool {
  for i in 0..<9 {
    if self.e[i] != other.e[i] {
      return false
    }
  }
  true
}
