// three.js Quaternion 迁移:不可变风格。
// 从 Euler 构造按 three.js 默认 XYZ 序(内在序 R = Rx*Ry*Rz 应用于列向量)。

///| 四元数 (x, y, z, w)
pub(all) struct Quaternion {
  x : Double
  y : Double
  z : Double
  w : Double
} derive(Debug)

pub extend Quaternion with Debug::{to_repr}

///| 单位四元数
pub fn Quaternion::identity() -> Quaternion {
  { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
}

///| 从轴+弧度角构造(轴需已单位化;不做归一化,three.js setFromAxisAngle 同式)
pub fn Quaternion::from_axis_angle(
  axis : Vector3,
  angle : Double,
) -> Quaternion {
  let h = angle / 2.0
  let s = @math.sin(h)
  {
    x: axis.x * s,
    y: axis.y * s,
    z: axis.z * s,
    w: @math.cos(h),
  }
}

///| 从 Euler(XYZ 序)构造,与 three.js Quaternion.setFromEuler 一致
pub fn Quaternion::from_euler(e : Euler) -> Quaternion {
  let c1 = @math.cos(e.x / 2.0)
  let c2 = @math.cos(e.y / 2.0)
  let c3 = @math.cos(e.z / 2.0)
  let s1 = @math.sin(e.x / 2.0)
  let s2 = @math.sin(e.y / 2.0)
  let s3 = @math.sin(e.z / 2.0)
  {
    x: s1 * c2 * c3 + c1 * s2 * s3,
    y: c1 * s2 * c3 - s1 * c2 * s3,
    z: s1 * s2 * c3 + c1 * c2 * s3,
    w: c1 * c2 * c3 - s1 * s2 * s3,
  }
}

///| 四元数乘法(旋转复合:this 后接 other)
pub fn Quaternion::multiply(
  self : Quaternion,
  other : Quaternion,
) -> Quaternion {
  let q1 = self
  let q2 = other
  {
    x: q1.x * q2.w + q1.w * q2.x + q1.y * q2.z - q1.z * q2.y,
    y: q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
    z: q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
    w: q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
  }
}

///| 共轭(单位四元数即逆)
pub fn Quaternion::invert(self : Quaternion) -> Quaternion {
  { x: -self.x, y: -self.y, z: -self.z, w: self.w }
}

///| 范数平方
pub fn Quaternion::length2(self : Quaternion) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
}

///| 单位化
pub fn Quaternion::normalize(self : Quaternion) -> Quaternion {
  let len = self.length2().sqrt()
  if len == 0.0 {
    return Quaternion::identity()
  }
  {
    x: self.x / len,
    y: self.y / len,
    z: self.z / len,
    w: self.w / len,
  }
}

///| 点积
pub fn Quaternion::dot(self : Quaternion, other : Quaternion) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z +
  self.w * other.w
}

///| 球面线性插值(dot<0 时对 other 全分量取反走短弧,再按 theta 精确式
///| 插值;three.js Quaternion.slerp 同式)
pub fn Quaternion::slerp(
  self : Quaternion,
  other : Quaternion,
  t : Double,
) -> Quaternion {
  let a = self
  let mut bx = other.x
  let mut by = other.y
  let mut bz = other.z
  let mut bw = other.w
  let mut d = a.dot(other)
  if d < 0.0 {
    bx = -bx
    by = -by
    bz = -bz
    bw = -bw
    d = -d
  }
  let mut s = 1.0 - t
  if d < 0.9995 {
    // slerp 精确式:s = sin((1-t)θ)/sinθ,t = sin(tθ)/sinθ
    let theta = @math.acos(d)
    let sin_theta = @math.sin(theta)
    s = @math.sin(s * theta) / sin_theta
    let t2 = @math.sin(t * theta) / sin_theta
    {
      x: a.x * s + bx * t2,
      y: a.y * s + by * t2,
      z: a.z * s + bz * t2,
      w: a.w * s + bw * t2,
    }
  } else {
    // 小角度:线性插值后归一化
    let lerped : Quaternion = {
      x: a.x * s + bx * t,
      y: a.y * s + by * t,
      z: a.z * s + bz * t,
      w: a.w * s + bw * t,
    }
    lerped.normalize()
  }
}

///| 旋转应用到向量
pub fn Quaternion::apply(self : Quaternion, v : Vector3) -> Vector3 {
  let q = self
  // v' = q * (0,v) * q^-1 展开式(three.js applyQuaternion)
  let qx = q.x
  let qy = q.y
  let qz = q.z
  let qw = q.w
  let ix = qw * v.x + qy * v.z - qz * v.y
  let iy = qw * v.y + qz * v.x - qx * v.z
  let iz = qw * v.z + qx * v.y - qy * v.x
  let iw = -qx * v.x - qy * v.y - qz * v.z
  {
    x: ix * qw + iw * -qx + iy * -qz - iz * -qy,
    y: iy * qw + iw * -qy + iz * -qx - ix * -qz,
    z: iz * qw + iw * -qz + ix * -qy - iy * -qx,
  }
}

///| 转为 4x4 旋转矩阵(列主序)
pub fn Quaternion::to_matrix4(self : Quaternion) -> Matrix4 {
  let { x, y, z, w } = self
  let x2 = x + x
  let y2 = y + y
  let z2 = z + z
  let xx = x * x2
  let xy = x * y2
  let xz = x * z2
  let yy = y * y2
  let yz = y * z2
  let zz = z * z2
  let wx = w * x2
  let wy = w * y2
  let wz = w * z2
  let e = Array::make(16, 0.0)
  e[0] = 1.0 - (yy + zz)
  e[1] = xy + wz
  e[2] = xz - wy
  e[4] = xy - wz
  e[5] = 1.0 - (xx + zz)
  e[6] = yz + wx
  e[8] = xz + wy
  e[9] = yz - wx
  e[10] = 1.0 - (xx + yy)
  e[15] = 1.0
  { e, }
}
