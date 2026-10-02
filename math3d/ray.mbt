// three.js Ray 迁移:射线(原点+方向),不可变风格,供拾取/投射使用。

///| p + v*s(three.js Vector3.addScaledVector 同式;供本包多文件复用)
fn vec3_add_scaled(p : Vector3, v : Vector3, s : Double) -> Vector3 {
  p.add(v.multiply_scalar(s))
}

///| 射线(origin 为起点,direction 应为单位方向)
pub(all) struct Ray {
  origin : Vector3
  direction : Vector3
} derive(Debug)

pub extend Ray with Debug::{to_repr}

///| 构造
pub fn Ray::new(origin : Vector3, direction : Vector3) -> Ray {
  { origin, direction }
}

///| 默认射线(origin=(0,0,0)、direction=(0,0,-1);three.js 构造默认)
pub fn Ray::default() -> Ray {
  { origin: Vector3::zero(), direction: Vector3::new(0.0, 0.0, -1.0) }
}

///| 沿射线取距原点 t 处的点(origin + direction*t)
pub fn Ray::at(self : Ray, t : Double) -> Vector3 {
  vec3_add_scaled(self.origin, self.direction, t)
}

///| 调整方向指向目标点((v-origin) 归一化)
pub fn Ray::look_at(self : Ray, v : Vector3) -> Ray {
  { origin: self.origin, direction: v.sub(self.origin).normalize() }
}

///| 原点沿方向推进 t
pub fn Ray::recast(self : Ray, t : Double) -> Ray {
  { origin: self.at(t), direction: self.direction }
}

///| 射线上离给定点最近的点(投影落在原点后方时返回原点)
pub fn Ray::closest_point_to_point(
  self : Ray,
  point : Vector3,
) -> Vector3 {
  let direction_distance = point.sub(self.origin).dot(self.direction)
  if direction_distance < 0.0 {
    return self.origin
  }
  vec3_add_scaled(self.origin, self.direction, direction_distance)
}

///| 射线到点的距离
pub fn Ray::distance_to_point(self : Ray, point : Vector3) -> Double {
  self.distance_sq_to_point(point).sqrt()
}

///| 射线到点的距离平方(点在原点后方时按到原点算)
pub fn Ray::distance_sq_to_point(self : Ray, point : Vector3) -> Double {
  let direction_distance = point.sub(self.origin).dot(self.direction)
  if direction_distance < 0.0 {
    return self.origin.distance_to_squared(point)
  }
  let closest = vec3_add_scaled(
    self.origin,
    self.direction,
    direction_distance,
  )
  closest.distance_to_squared(point)
}

// 射线-线段最近距离核心(GeometricTools DistRaySegment;
// 返回 (距离平方, 射线上参数 s0, 线段上参数 s1),
// three.js distanceSqToSegment 的 6 个区域 + 平行分支同式)
fn ray_segment_closest(
  ray : Ray,
  v0 : Vector3,
  v1 : Vector3,
) -> (Double, Double, Double) {
  let seg_center = v0.add(v1).multiply_scalar(0.5)
  let seg_dir = v1.sub(v0).normalize()
  let diff = ray.origin.sub(seg_center)
  let seg_extent = v0.distance_to(v1) * 0.5
  let a01 = -ray.direction.dot(seg_dir)
  let b0 = diff.dot(ray.direction)
  let b1 = -diff.dot(seg_dir)
  let c = diff.length2()
  let det = (1.0 - a01 * a01).abs()
  if det > 0.0 {
    // 射线与线段不平行
    let s0_raw = a01 * b1 - b0
    let s1_raw = a01 * b0 - b1
    let ext_det = seg_extent * det
    if s0_raw >= 0.0 {
      if s1_raw >= -ext_det {
        if s1_raw <= ext_det {
          // region 0:两者内部取最小
          let inv_det = 1.0 / det
          let s0 = s0_raw * inv_det
          let s1 = s1_raw * inv_det
          let sqr_dist = s0 *
            (s0 + a01 * s1 + 2.0 * b0) +
            s1 *
            (a01 * s0 + s1 + 2.0 * b1) +
            c
          (sqr_dist, s0, s1)
        } else {
          // region 1
          let s1 = seg_extent
          let s0 = max_double(0.0, -(a01 * s1 + b0))
          (-s0 * s0 + s1 * (s1 + 2.0 * b1) + c, s0, s1)
        }
      } else {
        // region 5
        let s1 = -seg_extent
        let s0 = max_double(0.0, -(a01 * s1 + b0))
        (-s0 * s0 + s1 * (s1 + 2.0 * b1) + c, s0, s1)
      }
    } else if s1_raw <= -ext_det {
      // region 4
      let s0 = max_double(0.0, -(-a01 * seg_extent + b0))
      let s1 = if s0 > 0.0 {
        -seg_extent
      } else {
        min_double(max_double(-seg_extent, -b1), seg_extent)
      }
      (-s0 * s0 + s1 * (s1 + 2.0 * b1) + c, s0, s1)
    } else if s1_raw <= ext_det {
      // region 3
      let s1 = min_double(max_double(-seg_extent, -b1), seg_extent)
      (s1 * (s1 + 2.0 * b1) + c, 0.0, s1)
    } else {
      // region 2
      let s0 = max_double(0.0, -(a01 * seg_extent + b0))
      let s1 = if s0 > 0.0 {
        seg_extent
      } else {
        min_double(max_double(-seg_extent, -b1), seg_extent)
      }
      (-s0 * s0 + s1 * (s1 + 2.0 * b1) + c, s0, s1)
    }
  } else {
    // 射线与线段平行
    let s1 = if a01 > 0.0 { -seg_extent } else { seg_extent }
    let s0 = max_double(0.0, -(a01 * s1 + b0))
    (-s0 * s0 + s1 * (s1 + 2.0 * b1) + c, s0, s1)
  }
}

///| 射线与线段的距离平方(three.js distanceSqToSegment)
pub fn Ray::distance_sq_to_segment(
  self : Ray,
  v0 : Vector3,
  v1 : Vector3,
) -> Double {
  let (sqr_dist, _, _) = ray_segment_closest(self, v0, v1)
  sqr_dist
}

///| 射线与线段的最近信息:(距离平方, 射线上最近点, 线段上最近点)
///| (对应 three.js distanceSqToSegment 的两个 optional target 出参)
pub fn Ray::distance_sq_to_segment_with_points(
  self : Ray,
  v0 : Vector3,
  v1 : Vector3,
) -> (Double, Vector3, Vector3) {
  let (sqr_dist, s0, s1) = ray_segment_closest(self, v0, v1)
  let seg_center = v0.add(v1).multiply_scalar(0.5)
  let seg_dir = v1.sub(v0).normalize()
  let point_on_ray = vec3_add_scaled(self.origin, self.direction, s0)
  let point_on_segment = vec3_add_scaled(seg_center, seg_dir, s1)
  (sqr_dist, point_on_ray, point_on_segment)
}

///| 与球求交:返回靠射线前方的交点(射线在球内时返回出口点);
///| 不相交或空球返回 None(three.js intersectSphere 同式)
pub fn Ray::intersect_sphere(
  self : Ray,
  sphere : Sphere,
) -> Vector3? {
  if sphere.radius < 0.0 {
    return None // 空球
  }
  let to_center = sphere.center.sub(self.origin)
  let tca = to_center.dot(self.direction)
  let d2 = to_center.dot(to_center) - tca * tca
  let radius2 = sphere.radius * sphere.radius
  if d2 > radius2 {
    return None
  }
  let thc = (radius2 - d2).sqrt()
  // t0=入点,t1=出点
  let t0 = tca - thc
  let t1 = tca + thc
  if t1 < 0.0 {
    return None // 两交点都在射线后方
  }
  if t0 < 0.0 {
    return Some(self.at(t1)) // 射线起点在球内,返回出口点
  }
  Some(self.at(t0))
}

///| 与球相交测试(空球恒 false)
pub fn Ray::intersects_sphere(self : Ray, sphere : Sphere) -> Bool {
  if sphere.radius < 0.0 {
    return false
  }
  self.distance_sq_to_point(sphere.center) <=
  (sphere.radius * sphere.radius)
}

///| 到平面的距离参数 t(射线在平面上返回 0;平行不共面或交点在
///| 射线后方返回 None,three.js distanceToPlane 同式)
pub fn Ray::distance_to_plane(self : Ray, plane : Plane) -> Double? {
  let denominator = plane.normal.dot(self.direction)
  if denominator == 0.0 {
    // 平行:原点在平面上返回 0,否则无交
    if plane.distance_to_point(self.origin) == 0.0 {
      return Some(0.0)
    }
    return None
  }
  let t = -(self.origin.dot(plane.normal) + plane.constant) / denominator
  if t >= 0.0 {
    Some(t)
  } else {
    None
  }
}

///| 与平面求交(无交返回 None)
pub fn Ray::intersect_plane(self : Ray, plane : Plane) -> Vector3? {
  match self.distance_to_plane(plane) {
    Some(t) => Some(self.at(t))
    None => None
  }
}

///| 与平面相交测试(原点在平面上、或射线朝向平面时为 true)
pub fn Ray::intersects_plane(self : Ray, plane : Plane) -> Bool {
  let dist_to_point = plane.distance_to_point(self.origin)
  if dist_to_point == 0.0 {
    return true
  }
  let denominator = plane.normal.dot(self.direction)
  denominator * dist_to_point < 0.0
}

///| 与包围盒求交(slab 法;方向分量为 0 时按 ±∞ 区间与 NaN 传播处理,
///| three.js intersectBox 同式)。返回靠射线前方的交点,无交返回 None
pub fn Ray::intersect_box(self : Ray, box : Box3) -> Vector3? {
  let invdirx = 1.0 / self.direction.x
  let invdiry = 1.0 / self.direction.y
  let invdirz = 1.0 / self.direction.z
  let origin = self.origin
  let (tmin0, tmax0) = if invdirx >= 0.0 {
    (
      (box.min.x - origin.x) * invdirx,
      (box.max.x - origin.x) * invdirx,
    )
  } else {
    (
      (box.max.x - origin.x) * invdirx,
      (box.min.x - origin.x) * invdirx,
    )
  }
  let mut tmin = tmin0
  let mut tmax = tmax0
  let (tymin, tymax) = if invdiry >= 0.0 {
    (
      (box.min.y - origin.y) * invdiry,
      (box.max.y - origin.y) * invdiry,
    )
  } else {
    (
      (box.max.y - origin.y) * invdiry,
      (box.min.y - origin.y) * invdiry,
    )
  }
  if tmin > tymax || tymin > tmax {
    return None
  }
  // NaN 判定:x !== x 等价 JS isNaN
  if tymin > tmin || tmin != tmin {
    tmin = tymin
  }
  if tymax < tmax || tmax != tmax {
    tmax = tymax
  }
  let (tzmin, tzmax) = if invdirz >= 0.0 {
    (
      (box.min.z - origin.z) * invdirz,
      (box.max.z - origin.z) * invdirz,
    )
  } else {
    (
      (box.max.z - origin.z) * invdirz,
      (box.min.z - origin.z) * invdirz,
    )
  }
  if tmin > tzmax || tzmin > tmax {
    return None
  }
  if tzmin > tmin || tmin != tmin {
    tmin = tzmin
  }
  if tzmax < tmax || tmax != tmax {
    tmax = tzmax
  }
  // 返回靠射线正向(正侧)最近的点
  if tmax < 0.0 {
    return None
  }
  Some(self.at(if tmin >= 0.0 { tmin } else { tmax }))
}

///| 与包围盒相交测试(intersect_box 非空即相交)
pub fn Ray::intersects_box(self : Ray, box : Box3) -> Bool {
  match self.intersect_box(box) {
    Some(_) => true
    None => false
  }
}

///| 与三角形求交(watertight 算法,Woop/Benthin/Wald JCGT 2013;
///| backface_culling 为 true 时背面剔除;无交返回 None。
///| three.js intersectTriangle 同式)
pub fn Ray::intersect_triangle(
  self : Ray,
  a : Vector3,
  b : Vector3,
  c : Vector3,
  backface_culling : Bool,
) -> Vector3? {
  let origin = self.origin
  let direction = self.direction
  let dx = direction.x
  let dy = direction.y
  let dz = direction.z
  // 三角形顶点相对射线原点
  let aox = a.x - origin.x
  let aoy = a.y - origin.y
  let aoz = a.z - origin.z
  let box = b.x - origin.x
  let boy = b.y - origin.y
  let boz = b.z - origin.z
  let cox = c.x - origin.x
  let coy = c.y - origin.y
  let coz = c.z - origin.z
  // 取射线方向绝对值最大的分量为 kz 轴,kz<0 时交换 kx/ky 保持绕序;
  // 三分支各产出 12 元组:(dkx,dky,dkz, akx,aky,akz, bkx,bky,bkz, ckx,cky,ckz)
  let adx = dx.abs()
  let ady = dy.abs()
  let adz = dz.abs()
  let (dkx, dky, dkz, akx, aky, akz, bkx, bky, bkz, ckx, cky, ckz) = if adx >= ady &&
    adx >= adz {
    // kz=x
    if dx >= 0.0 {
      (dy, dz, dx, aoy, aoz, aox, boy, boz, box, coy, coz, cox)
    } else {
      (dz, dy, dx, aoz, aoy, aox, boz, boy, box, coz, coy, cox)
    }
  } else if ady >= adz {
    // kz=y
    if dy >= 0.0 {
      (dz, dx, dy, aoz, aox, aoy, boz, box, boy, coz, cox, coy)
    } else {
      (dx, dz, dy, aox, aoz, aoy, box, boz, boy, cox, coz, coy)
    }
  } else {
    // kz=z
    if dz >= 0.0 {
      (dx, dy, dz, aox, aoy, aoz, box, boy, boz, cox, coy, coz)
    } else {
      (dy, dx, dz, aoy, aox, aoz, boy, box, boz, coy, cox, coz)
    }
  }
  // 零方向无最大轴,不可能相交
  if dkz == 0.0 {
    return None
  }
  // 剪切常数:把射线对齐到 +kz 轴
  let sx = dkx / dkz
  let sy = dky / dkz
  let sz = 1.0 / dkz
  // 剪切缩放后的顶点
  let ax = akx - sx * akz
  let ay = aky - sy * akz
  let bx = bkx - sx * bkz
  let by = bky - sy * bkz
  let cx = ckx - sx * ckz
  let cy = cky - sy * ckz
  // 缩放后的重心坐标(带符号边函数);剪切保证共享边对相邻三角形
  // 求值一致,射线不会从缝隙漏过
  let u = cx * by - cy * bx
  let v = ax * cy - ay * cx
  let w = bx * ay - by * ax
  if backface_culling {
    if u < 0.0 || v < 0.0 || w < 0.0 {
      return None
    }
  } else if (u < 0.0 || v < 0.0 || w < 0.0) &&
    (u > 0.0 || v > 0.0 || w > 0.0) {
    return None
  }
  let det = u + v + w
  // 射线与三角形共面
  if det == 0.0 {
    return None
  }
  // 缩放后的命中距离;t = tScaled/det 必须在原点前方
  let t_scaled = sz * (u * akz + v * bkz + w * ckz)
  let behind = if det > 0.0 { t_scaled < 0.0 } else { t_scaled > 0.0 }
  if behind {
    return None
  }
  Some(self.at(t_scaled / det))
}

///| 施加 4x4 变换(原点按点变换,方向按方向变换并归一)
pub fn Ray::apply_matrix4(self : Ray, matrix : Matrix4) -> Ray {
  {
    origin: matrix.apply_point(self.origin),
    direction: matrix.apply_direction(self.direction),
  }
}

///| 分量相等(精确)
pub fn Ray::equals(self : Ray, other : Ray) -> Bool {
  self.origin.equals(other.origin) &&
  self.direction.equals(other.direction)
}
