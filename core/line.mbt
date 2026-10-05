// three.js Line 迁移:折线与线段对(A7,瞄准线/弹道/血条的基础)。
// Line = 顶点依次相连的条带(WGPU LINE_STRIP);LineSegments = 两两一档的
// 独立线段(WGPU LINE_LIST),网格线等成对端点场景零重复顶点。
// 材质走 LineBasicMaterial + basic 族管线(mvp + 主色,顶点色可选乘)。
// Line/LineSegments 为零字段标记类型(静态构造器命名空间),与 Mesh::new
// 同构:构造产出场景图节点 Object3D,直接 scene.add 挂载。

///|
/// 折线标记类型(three.js Line;构造产出 Object3D 节点)
pub(all) struct Line {}

///|
/// 独立线段对标记类型(three.js LineSegments;构造产出 Object3D 节点)
pub(all) struct LineSegments {}

///|
/// 折线(three.js Line:几何顶点首尾相连;线不投/不收阴影——A5 阴影
/// 深度管线按三角面光栅化,three.js Line.castShadow 默认 false 同语义)
pub fn Line::new(geometry : BufferGeometry, material : Material) -> Object3D {
  let o = Object3D::new()
  o.mesh = Some({
    geometry,
    material,
    cast_shadow: false,
    receive_shadow: false,
    topology: 1,
  })
  o
}

///|
/// 折线从位置数组直接构建(xyz 连续;colors? 给出顶点色时写入几何
/// 并置材质 vertex_colors=true,渲染时乘进主色)
pub fn Line::from_positions(
  positions : Array[Double],
  material : Material,
  colors? : Array[Double],
) -> Object3D {
  let geo = BufferGeometry::from_positions(positions)
  match colors {
    Some(cs) => {
      geo.set_colors(cs)
      material.vertex_colors = true
    }
    None => ()
  }
  Line::new(geo, material)
}

///|
/// 独立线段对(three.js LineSegments:顶点两两一档,(v0,v1)(v2,v3)…;
/// 阴影语义同 Line,不投不收)
pub fn LineSegments::new(
  geometry : BufferGeometry,
  material : Material,
) -> Object3D {
  let o = Object3D::new()
  o.mesh = Some({
    geometry,
    material,
    cast_shadow: false,
    receive_shadow: false,
    topology: 2,
  })
  o
}

///|
/// 线段对从位置数组直接构建(端点对 xyz 连续;colors? 同 Line)
pub fn LineSegments::from_positions(
  positions : Array[Double],
  material : Material,
  colors? : Array[Double],
) -> Object3D {
  let geo = BufferGeometry::from_positions(positions)
  match colors {
    Some(cs) => {
      geo.set_colors(cs)
      material.vertex_colors = true
    }
    None => ()
  }
  LineSegments::new(geo, material)
}
