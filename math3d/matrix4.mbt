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

///| 求逆(奇异矩阵返回全零矩阵,three.js Matrix4.invert 同语义)
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
    return { e: Array::make(16, 0.0) }
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

///| 透视投影矩阵(fov_y/aspect/near/far;深度采用 WebGPU 裁剪域 z∈[0,1],
///| 对应 three.js makePerspective 的 WebGPUCoordinateSystem 分支,与本仓
///| WebGPU 渲染器的 depth24plus+LESS 约定一致)
pub fn Matrix4::make_perspective(
  fov_y : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> Matrix4 {
  let f = 1.0 / @math.tan(fov_y / 2.0)
  let m = Array::make(16, 0.0)
  m[0] = f / aspect
  m[5] = f
  m[10] = -far / (far - near)
  m[11] = -1.0
  m[14] = (-far * near) / (far - near)
  { e: m }
}

///| 正交投影矩阵(WebGPU 裁剪域 z∈[0,1],对应 three.js makeOrthographic
///| 的 WebGPUCoordinateSystem 分支)
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
  m[0] = -2.0 * w
  m[5] = 2.0 / (top - bottom)
  m[10] = -1.0 / (far - near)
  m[12] = (left + right) * w
  m[13] = -(top + bottom) / (top - bottom)
  m[14] = -near / (far - near)
  m[15] = 1.0
  { e: m }
}

///| 朝向矩阵:只设置旋转部分(不含平移;eye==target 回退 z=(0,0,1),
///| up 与视线平行时对 z 加 0.0001 扰动后重叉积,three.js Matrix4.lookAt
///| 同式;视图矩阵 = 本结果配合平移使用或由相机世界矩阵求逆得到)
pub fn Matrix4::make_look_at(
  eye : Vector3,
  target : Vector3,
  up : Vector3,
) -> Matrix4 {
  let mut z = eye.sub(target)
  if z.length2() == 0.0 {
    // eye 与 target 重合
    z = { x: 0.0, y: 0.0, z: 1.0 }
  }
  z = z.normalize()
  let mut x = up.cross(z)
  if x.length2() == 0.0 {
    // up 与 z 平行:对 z 微扰后重叉积(three.js 同式)
    z = if up.z.abs() == 1.0 {
      { x: z.x + 0.0001, y: z.y, z: z.z }
    } else {
      { x: z.x, y: z.y, z: z.z + 0.0001 }
    }
    z = z.normalize()
    x = up.cross(z)
  }
  x = x.normalize()
  let y = z.cross(x)
  // 基向量按列排布(three.js lookAt 同式:te[0]=x.x、te[4]=y.x、te[8]=z.x)
  let m = Array::make(16, 0.0)
  m[0] = x.x
  m[1] = x.y
  m[2] = x.z
  m[4] = y.x
  m[5] = y.y
  m[6] = y.z
  m[8] = z.x
  m[9] = z.y
  m[10] = z.z
  m[15] = 1.0
  { e: m }
}

///| 变换点(w=1,除以 w 做透视归一;w=0 时得 ±Infinity/NaN,three.js
///| applyMatrix4 同式)
pub fn Matrix4::apply_point(
  self : Matrix4,
  p : Vector3,
) -> Vector3 {
  let m = self.e
  let w = 1.0 / (m[3] * p.x + m[7] * p.y + m[11] * p.z + m[15])
  {
    x: (m[0] * p.x + m[4] * p.y + m[8] * p.z + m[12]) * w,
    y: (m[1] * p.x + m[5] * p.y + m[9] * p.z + m[13]) * w,
    z: (m[2] * p.x + m[6] * p.y + m[10] * p.z + m[14]) * w,
  }
}

///| 变换方向(w=0,不做平移,变换后归一化;零向量输入返回零,three.js
///| transformDirection 同式)
pub fn Matrix4::apply_direction(
  self : Matrix4,
  v : Vector3,
) -> Vector3 {
  let m = self.e
  let d : Vector3 = {
    x: m[0] * v.x + m[4] * v.y + m[8] * v.z,
    y: m[1] * v.x + m[5] * v.y + m[9] * v.z,
    z: m[2] * v.x + m[6] * v.y + m[10] * v.z,
  }
  let len = d.length()
  d.multiply_scalar(1.0 / (if len == 0.0 { 1.0 } else { len }))
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

///| 分解为 (平移, 旋转, 缩放)(假定底行 [0,0,0,1];旋转部分按各列长度
///| 去缩放后提取四元数,det<0(镜像)时 sx 取负,three.js Matrix4.decompose
///| 同式)
pub fn Matrix4::decompose(
  self : Matrix4,
) -> (Vector3, Quaternion, Vector3) {
  let m = self.e
  let position : Vector3 = { x: m[12], y: m[13], z: m[14] }
  // determinantAffine:左上 3x3 行列式
  let det = m[0] * (m[5] * m[10] - m[6] * m[9]) -
    m[4] * (m[1] * m[10] - m[2] * m[9]) +
    m[8] * (m[1] * m[6] - m[2] * m[5])
  if det == 0.0 {
    return (position, Quaternion::identity(), Vector3::new(1.0, 1.0, 1.0))
  }
  let cx : Vector3 = { x: m[0], y: m[1], z: m[2] }
  let sx = cx.length()
  let cy : Vector3 = { x: m[4], y: m[5], z: m[6] }
  let sy = cy.length()
  let cz : Vector3 = { x: m[8], y: m[9], z: m[10] }
  let sz = cz.length()
  // 行列式为负(镜像)时反转一个缩放分量
  let sx = if det < 0.0 { -sx } else { sx }
  // 旋转部分去缩放后提取四元数
  let isx = 1.0 / sx
  let isy = 1.0 / sy
  let isz = 1.0 / sz
  let rot = Array::make(16, 0.0)
  rot[0] = m[0] * isx
  rot[1] = m[1] * isx
  rot[2] = m[2] * isx
  rot[4] = m[4] * isy
  rot[5] = m[5] * isy
  rot[6] = m[6] * isy
  rot[8] = m[8] * isz
  rot[9] = m[9] * isz
  rot[10] = m[10] * isz
  rot[15] = 1.0
  let rot_m : Matrix4 = { e: rot, }
  let quat = rot_m.to_quaternion()
  (position, quat, Vector3::new(sx, sy, sz))
}
