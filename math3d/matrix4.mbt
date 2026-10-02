// three.js Matrix4 迁移:列主序 4x4(与 WGSL/着色器一致),不可变风格。

///| 列主序 4x4 矩阵(16 元素,按列排布,与 GPU 端一致)
pub(all) struct Matrix4 {
  // e[col*4 + row]
  e : Array[Double]
} derive(Debug)

///| 单位矩阵
pub fn Matrix4::identity() -> Matrix4 {
  let e = Array::make(16, 0.0)
  e[0] = 1.0
  e[5] = 1.0
  e[10] = 1.0
  e[15] = 1.0
  { e, }
}

///| 从 16 元素构造(列主序)
pub fn Matrix4::from_array(arr : Array[Double]) -> Matrix4 {
  let e = Array::make(16, 0.0)
  for i in 0..<16 {
    e[i] = arr[i]
  }
  { e, }
}

///| 矩阵乘法(this * other)
pub fn Matrix4::multiply(self : Matrix4, other : Matrix4) -> Matrix4 {
  let a = self.e
  let b = other.e
  let r = Array::make(16, 0.0)
  for col in 0..<4 {
    for row in 0..<4 {
      let mut sum = 0.0
      for k in 0..<4 {
        sum = sum + a[k * 4 + row] * b[col * 4 + k]
      }
      r[col * 4 + row] = sum
    }
  }
  { e: r }
}

///| 转置
pub fn Matrix4::transpose(self : Matrix4) -> Matrix4 {
  let a = self.e
  let r = Array::make(16, 0.0)
  for col in 0..<4 {
    for row in 0..<4 {
      r[row * 4 + col] = a[col * 4 + row]
    }
  }
  { e: r }
}

///| 求逆(奇异矩阵返回单位阵,three.js 同语义 setFromMatrix4 对应物)
pub fn Matrix4::invert(self : Matrix4) -> Matrix4 {
  let m = self.e
  let inv = Array::make(16, 0.0)
  inv[0] = m[5] * m[10] * m[15] -
    m[5] * m[11] * m[14] -
    m[9] * m[6] * m[15] +
    m[9] * m[7] * m[14] +
    m[13] * m[6] * m[11] -
    m[13] * m[7] * m[10]
  inv[4] = -m[4] * m[10] * m[15] +
    m[4] * m[11] * m[14] +
    m[8] * m[6] * m[15] -
    m[8] * m[7] * m[14] -
    m[12] * m[6] * m[11] +
    m[12] * m[7] * m[10]
  inv[8] = m[4] * m[9] * m[15] -
    m[4] * m[11] * m[13] -
    m[8] * m[5] * m[15] +
    m[8] * m[7] * m[13] +
    m[12] * m[5] * m[11] -
    m[12] * m[7] * m[9]
  inv[12] = -m[4] * m[9] * m[14] +
    m[4] * m[10] * m[13] +
    m[8] * m[5] * m[14] -
    m[8] * m[6] * m[13] -
    m[12] * m[5] * m[10] +
    m[12] * m[6] * m[9]
  inv[1] = -m[1] * m[10] * m[15] +
    m[1] * m[11] * m[14] +
    m[9] * m[2] * m[15] -
    m[9] * m[3] * m[14] -
    m[13] * m[2] * m[11] +
    m[13] * m[3] * m[10]
  inv[5] = m[0] * m[10] * m[15] -
    m[0] * m[11] * m[14] -
    m[8] * m[2] * m[15] +
    m[8] * m[3] * m[14] +
    m[12] * m[2] * m[11] -
    m[12] * m[3] * m[10]
  inv[9] = -m[0] * m[9] * m[15] +
    m[0] * m[11] * m[13] +
    m[8] * m[1] * m[15] -
    m[8] * m[3] * m[13] -
    m[12] * m[1] * m[11] +
    m[12] * m[3] * m[9]
  inv[13] = m[0] * m[9] * m[14] -
    m[0] * m[10] * m[13] -
    m[8] * m[1] * m[14] +
    m[8] * m[2] * m[13] +
    m[12] * m[1] * m[10] -
    m[12] * m[2] * m[9]
  inv[2] = m[1] * m[6] * m[15] -
    m[1] * m[7] * m[14] -
    m[5] * m[2] * m[15] +
    m[5] * m[3] * m[14] +
    m[13] * m[2] * m[7] -
    m[13] * m[3] * m[6]
  inv[6] = -m[0] * m[6] * m[15] +
    m[0] * m[7] * m[14] +
    m[4] * m[2] * m[15] -
    m[4] * m[3] * m[14] -
    m[12] * m[2] * m[7] +
    m[12] * m[3] * m[6]
  inv[10] = m[0] * m[5] * m[15] -
    m[0] * m[7] * m[13] -
    m[4] * m[1] * m[15] +
    m[4] * m[3] * m[13] +
    m[12] * m[1] * m[7] -
    m[12] * m[3] * m[5]
  inv[14] = -m[0] * m[5] * m[14] +
    m[0] * m[6] * m[13] +
    m[4] * m[1] * m[14] -
    m[4] * m[2] * m[13] -
    m[12] * m[1] * m[6] +
    m[12] * m[2] * m[5]
  inv[3] = -m[1] * m[6] * m[11] +
    m[1] * m[7] * m[10] +
    m[5] * m[2] * m[11] -
    m[5] * m[3] * m[10] -
    m[9] * m[2] * m[7] +
    m[9] * m[3] * m[6]
  inv[7] = m[0] * m[6] * m[11] -
    m[0] * m[7] * m[10] -
    m[4] * m[2] * m[11] +
    m[4] * m[3] * m[10] +
    m[8] * m[2] * m[7] -
    m[8] * m[3] * m[6]
  inv[11] = -m[0] * m[5] * m[11] +
    m[0] * m[7] * m[9] +
    m[4] * m[1] * m[11] -
    m[4] * m[3] * m[9] -
    m[8] * m[1] * m[7] +
    m[8] * m[3] * m[5]
  inv[15] = m[0] * m[5] * m[10] -
    m[0] * m[6] * m[9] -
    m[4] * m[1] * m[10] +
    m[4] * m[2] * m[9] +
    m[8] * m[1] * m[6] -
    m[8] * m[2] * m[5]
  let det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12]
  if det == 0.0 {
    return Matrix4::identity()
  }
  let det_inv = 1.0 / det
  let r = Array::make(16, 0.0)
  for i in 0..<16 {
    r[i] = inv[i] * det_inv
  }
  { e: r }
}

///| 平移矩阵
pub fn Matrix4::make_translation(x : Double, y : Double, z : Double) -> Matrix4 {
  let m = Matrix4::identity()
  m.e[12] = x
  m.e[13] = y
  m.e[14] = z
  m
}

///| 缩放矩阵
pub fn Matrix4::make_scale(x : Double, y : Double, z : Double) -> Matrix4 {
  let m = Matrix4::identity()
  m.e[0] = x
  m.e[5] = y
  m.e[10] = z
  m
}

///| 绕任意轴旋转矩阵(角度制->弧度由调用方负责,轴需已单位化)
pub fn Matrix4::make_rotation_axis(
  axis : Vector3,
  angle : Double,
) -> Matrix4 {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  let t = 1.0 - c
  let { x, y, z } = axis
  let m = Matrix4::identity()
  m.e[0] = x * x * t + c
  m.e[1] = y * x * t + z * s
  m.e[2] = z * x * t - y * s
  m.e[4] = x * y * t - z * s
  m.e[5] = y * y * t + c
  m.e[6] = z * y * t + x * s
  m.e[8] = x * z * t + y * s
  m.e[9] = y * z * t - x * s
  m.e[10] = z * z * t + c
  m
}

///| 透视投影矩阵(three.js PerspectiveCamera 同式;fov_y/aspect/near/far,near>0)
pub fn Matrix4::make_perspective(
  fov_y : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> Matrix4 {
  let f = 1.0 / @math.tan(fov_y / 2.0)
  let nf = 1.0 / (near - far)
  let m = Array::make(16, 0.0)
  m[0] = f / aspect
  m[5] = f
  m[10] = (far + near) * nf
  m[11] = -1.0
  m[14] = 2.0 * far * near * nf
  { e: m }
}

///| 正交投影矩阵
pub fn Matrix4::make_orthographic(
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
  near : Double,
  far : Double,
) -> Matrix4 {
  let m = Array::make(16, 0.0)
  let w = 1.0 / (left - right)
  let h = 1.0 / (top - bottom)
  let p = 1.0 / (near - far)
  m[0] = -2.0 * w
  m[5] = -2.0 * h
  m[10] = 2.0 * p
  m[12] = (left + right) * w
  m[13] = (top + bottom) * h
  m[14] = (far + near) * p
  m[15] = 1.0
  { e: m }
}

///| 视图矩阵(three.js Matrix4.lookAt 同式;eye/target/up)
pub fn Matrix4::make_look_at(
  eye : Vector3,
  target : Vector3,
  up : Vector3,
) -> Matrix4 {
  let z = eye.sub(target).normalize()
  let x = up.cross(z)
  // up 与视线共线时叉积退化,fallback 到正交轴(three.js 检查 length 为 0)
  let x = if x.length2() < 0.0000000001 {
    let alt = if up.x.abs() < 0.9 {
      Vector3::unit_x()
    } else {
      Vector3::unit_y()
    }
    alt.cross(z)
  } else {
    x
  }
  let x = x.normalize()
  let y = z.cross(x)
  let m = Array::make(16, 0.0)
  m[0] = x.x
  m[1] = y.x
  m[2] = z.x
  m[4] = x.y
  m[5] = y.y
  m[6] = z.y
  m[8] = x.z
  m[9] = y.z
  m[10] = z.z
  m[12] = -x.dot(eye)
  m[13] = -y.dot(eye)
  m[14] = -z.dot(eye)
  m[15] = 1.0
  { e: m }
}

///| 变换点(w=1,返回变换后 w 归一坐标)
pub fn Matrix4::apply_point(
  self : Matrix4,
  p : Vector3,
) -> Vector3 {
  let m = self.e
  let w = m[3] * p.x + m[7] * p.y + m[11] * p.z + m[15]
  if w == 0.0 {
    return Vector3::zero()
  }
  let iw = 1.0 / w
  {
    x: (m[0] * p.x + m[4] * p.y + m[8] * p.z + m[12]) * iw,
    y: (m[1] * p.x + m[5] * p.y + m[9] * p.z + m[13]) * iw,
    z: (m[2] * p.x + m[6] * p.y + m[10] * p.z + m[14]) * iw,
  }
}

///| 变换方向(w=0,不做平移与透视除法)
pub fn Matrix4::apply_direction(
  self : Matrix4,
  v : Vector3,
) -> Vector3 {
  let m = self.e
  {
    x: m[0] * v.x + m[4] * v.y + m[8] * v.z,
    y: m[1] * v.x + m[5] * v.y + m[9] * v.z,
    z: m[2] * v.x + m[6] * v.y + m[10] * v.z,
  }
}

///| 分量相等(精确)
pub fn Matrix4::equals(self : Matrix4, other : Matrix4) -> Bool {
  for i in 0..<16 {
    if self.e[i] != other.e[i] {
      return false
    }
  }
  true
}

pub extend Matrix4 with Debug::{to_repr}

///| 提取缩放(用于法线矩阵等)
pub fn Matrix4::max_scale_on_axis(self : Matrix4) -> Double {
  let m = self.e
  let sx = m[0] * m[0] + m[1] * m[1] + m[2] * m[2]
  let sy = m[4] * m[4] + m[5] * m[5] + m[6] * m[6]
  let sz = m[8] * m[8] + m[9] * m[9] + m[10] * m[10]
  let smax = if sx > sy { sx } else { sy }
  (if smax > sz { smax } else { sz }).sqrt()
}

///| 从旋转矩阵提取四元数(Shepperd 方法,three.js setFromRotationMatrix 同源)
pub fn Matrix4::to_quaternion(self : Matrix4) -> Quaternion {
  let m = self.e
  let trace = m[0] + m[5] + m[10]
  fn mk(w : Double, x : Double, y : Double, z : Double) -> Quaternion {
    let q : Quaternion = { x, y, z, w, }
    q.normalize()
  }
  if trace > 0.0 {
    let s = 0.5 / (trace + 1.0).sqrt()
    mk(0.25 / s, (m[6] - m[9]) * s, (m[8] - m[2]) * s, (m[1] - m[4]) * s)
  } else if m[0] > m[5] && m[0] > m[10] {
    let s = 2.0 * (1.0 + m[0] - m[5] - m[10]).sqrt()
    mk((m[6] - m[9]) / s, 0.25 * s, (m[4] + m[1]) / s, (m[8] + m[2]) / s)
  } else if m[5] > m[10] {
    let s = 2.0 * (1.0 + m[5] - m[0] - m[10]).sqrt()
    mk((m[8] - m[2]) / s, (m[4] + m[1]) / s, 0.25 * s, (m[9] + m[6]) / s)
  } else {
    let s = 2.0 * (1.0 + m[10] - m[0] - m[5]).sqrt()
    mk((m[1] - m[4]) / s, (m[8] + m[2]) / s, (m[9] + m[6]) / s, 0.25 * s)
  }
}
