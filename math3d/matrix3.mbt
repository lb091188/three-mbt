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

///| 法线矩阵:4x4 左上 3x3 的逆转置(three.js getNormalMatrix 同式:先取
///| 3x3 再求逆再转置;奇异时得零矩阵)
pub fn Matrix3::normal_from_matrix4(m : Matrix4) -> Matrix3 {
  Matrix3::from_matrix4(m).invert().transpose()
}

///| 求逆(奇异矩阵返回零矩阵,three.js Matrix3.invert 同语义)
pub fn Matrix3::invert(self : Matrix3) -> Matrix3 {
  let te = self.e
  let n11 = te[0]
  let n21 = te[1]
  let n31 = te[2]
  let n12 = te[3]
  let n22 = te[4]
  let n32 = te[5]
  let n13 = te[6]
  let n23 = te[7]
  let n33 = te[8]
  let t11 = n33 * n22 - n32 * n23
  let t12 = n32 * n13 - n33 * n12
  let t13 = n23 * n12 - n22 * n13
  let det = n11 * t11 + n21 * t12 + n31 * t13
  if det == 0.0 {
    return { e: Array::make(9, 0.0) }
  }
  let det_inv = 1.0 / det
  let r = Array::make(9, 0.0)
  r[0] = t11 * det_inv
  r[1] = (n31 * n23 - n33 * n21) * det_inv
  r[2] = (n32 * n21 - n31 * n22) * det_inv
  r[3] = t12 * det_inv
  r[4] = (n11 * n33 - n31 * n13) * det_inv
  r[5] = (n31 * n12 - n32 * n11) * det_inv
  r[6] = t13 * det_inv
  r[7] = (n21 * n13 - n23 * n11) * det_inv
  r[8] = (n11 * n22 - n21 * n12) * det_inv
  { e: r }
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
