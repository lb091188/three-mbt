// three.js Frustum 迁移:六平面视锥,供裁剪测试;不可变风格。

///| 裁剪坐标系(three.js WebGLCoordinateSystem=2000 / WebGPUCoordinateSystem=2001)
pub(all) enum CoordinateSystem {
  WebGL
  WebGPU
}

///| 由 three.js 坐标系常量值构造(2000=WebGL、2001=WebGPU;未知值返回 None)
pub fn CoordinateSystem::from_code(code : Int) -> CoordinateSystem? {
  match code {
    2000 => Some(WebGL)
    2001 => Some(WebGPU)
    _ => None
  }
}

///| 视锥(六个 Plane 围成;planes 顺序:左/右/上/下/远/近)
pub(all) struct Frustum {
  planes : Array[Plane]
} derive(Debug)

pub extend Frustum with Debug::{to_repr}

///| 默认视锥(六个默认平面;three.js 构造默认)
pub fn Frustum::new() -> Frustum {
  { planes: [Plane::default(), Plane::default(), Plane::default(), Plane::default(), Plane::default(), Plane::default()] }
}

///| 由六个平面构造
pub fn Frustum::from_planes(
  p0 : Plane,
  p1 : Plane,
  p2 : Plane,
  p3 : Plane,
  p4 : Plane,
  p5 : Plane,
) -> Frustum {
  { planes: [p0, p1, p2, p3, p4, p5] }
}

///| 从投影矩阵提取六平面(各平面归一化;WebGPU 坐标系 near 平面取
///| 第三行,WebGL 取 me3+me2 行;reversed_depth 时远近互换,
///| three.js setFromProjectionMatrix 同式)
pub fn Frustum::set_from_projection_matrix(
  m : Matrix4,
  coordinate_system : CoordinateSystem,
  reversed_depth : Bool,
) -> Frustum {
  let me = m.e
  let me0 = me[0]
  let me1 = me[1]
  let me2 = me[2]
  let me3 = me[3]
  let me4 = me[4]
  let me5 = me[5]
  let me6 = me[6]
  let me7 = me[7]
  let me8 = me[8]
  let me9 = me[9]
  let me10 = me[10]
  let me11 = me[11]
  let me12 = me[12]
  let me13 = me[13]
  let me14 = me[14]
  let me15 = me[15]
  let left = Plane::set_components(
    me3 - me0,
    me7 - me4,
    me11 - me8,
    me15 - me12,
  ).normalize()
  let right = Plane::set_components(
    me3 + me0,
    me7 + me4,
    me11 + me8,
    me15 + me12,
  ).normalize()
  let top = Plane::set_components(
    me3 + me1,
    me7 + me5,
    me11 + me9,
    me15 + me13,
  ).normalize()
  let bottom = Plane::set_components(
    me3 - me1,
    me7 - me5,
    me11 - me9,
    me15 - me13,
  ).normalize()
  let (far, near) = if reversed_depth {
    (
      Plane::set_components(me2, me6, me10, me14).normalize(),
      Plane::set_components(me3 - me2, me7 - me6, me11 - me10, me15 - me14)
        .normalize(),
    )
  } else {
    let far = Plane::set_components(
      me3 - me2,
      me7 - me6,
      me11 - me10,
      me15 - me14,
    ).normalize()
    let near = match coordinate_system {
      WebGL =>
        Plane::set_components(
          me3 + me2,
          me7 + me6,
          me11 + me10,
          me15 + me14,
        ).normalize()
      WebGPU => Plane::set_components(me2, me6, me10, me14).normalize()
    }
    (far, near)
  }
  { planes: [left, right, top, bottom, far, near] }
}

///| 与包围球相交测试(快速保守:球心到任一平面距离 < -radius 才剔除,
///| 不漏剔、可能误留)
pub fn Frustum::intersects_sphere(
  self : Frustum,
  sphere : Sphere,
) -> Bool {
  let neg_radius = -sphere.radius
  for i in 0..<6 {
    let distance = self.planes[i].distance_to_point(sphere.center)
    if distance < neg_radius {
      return false
    }
  }
  true
}

///| 与包围盒相交测试(快速保守:对每个平面取盒上离其最远的角点,
///| 全在平面负侧才剔除)
pub fn Frustum::intersects_box(self : Frustum, box : Box3) -> Bool {
  for i in 0..<6 {
    let plane = self.planes[i]
    // 法线分量为正取 max 端,否则取 min 端(离平面最远的角)
    let corner : Vector3 = {
      x: if plane.normal.x > 0.0 { box.max.x } else { box.min.x },
      y: if plane.normal.y > 0.0 { box.max.y } else { box.min.y },
      z: if plane.normal.z > 0.0 { box.max.z } else { box.min.z },
    }
    if plane.distance_to_point(corner) < 0.0 {
      return false
    }
  }
  true
}

///| 点是否在视锥内(含边界)
pub fn Frustum::contains_point(self : Frustum, point : Vector3) -> Bool {
  for i in 0..<6 {
    if self.planes[i].distance_to_point(point) < 0.0 {
      return false
    }
  }
  true
}
