// three.js 材质迁移:Basic(纯色)与受光照的 Lambert/Phong。

///| 材质(Basic 不受光照;Lambert/Phong 参与光照)
pub(all) struct Material {
  /// 类型标签:0=Basic、1=Lambert、2=Phong
  kind : Int
  /// 主色(漫反射)
  mut color : @math3d.Color
  /// 自发光色(仅 Lambert/Phong 生效,Basic 恒为黑)
  mut emissive : @math3d.Color
  /// 高光色(仅 Phong 生效)
  mut specular : @math3d.Color
  /// 高光锐度,越大高光越锐(仅 Phong 生效)
  mut shininess : Double
  /// 漫反射贴图(three.js map;None = 纯色。lit 管线采样乘进主色,
  /// 无贴图时渲染层绑 1×1 白纹理保持同一管线)
  mut map : Texture?
  /// 顶点色开关(three.js vertexColors;几何 colors 属性存在时乘进主色)
  mut vertex_colors : Bool
  /// 是否受场景雾影响(three.js material.fog,默认 true;天空穹关)
  mut fog : Bool
}

///| Basic 材质(不受光照的纯色)
pub fn Material::basic(color : @math3d.Color) -> Material {
  {
    kind: 0,
    color,
    emissive: @math3d.Color::black(),
    specular: @math3d.Color::black(),
    shininess: 30.0,
    map: None,
    vertex_colors: false,
    fog: true,
  }
}

///| Lambert 材质(漫反射受光,无高光;emissive 为自发光色,
///| three.js MeshLambertMaterial 默认 color=白、emissive=黑)
pub fn Material::lambert(
  color : @math3d.Color,
  emissive : @math3d.Color
) -> Material {
  {
    kind: 1,
    color,
    emissive,
    specular: @math3d.Color::black(),
    shininess: 30.0,
    map: None,
    vertex_colors: false,
    fog: true,
  }
}

///| Phong 材质(Blinn-Phong 高光;three.js MeshPhongMaterial 默认
///| color=白、specular=#111111、shininess=30、emissive=黑)
pub fn Material::phong(
  color : @math3d.Color,
  specular : @math3d.Color,
  shininess : Double,
  emissive : @math3d.Color
) -> Material {
  {
    kind: 2,
    color,
    emissive,
    specular,
    shininess,
    map: None,
    vertex_colors: false,
    fog: true,
  }
}

///| 是否 Basic(对应 three.js isMeshBasicMaterial)
pub fn Material::is_basic(self : Material) -> Bool {
  self.kind == 0
}

///| 是否 Lambert(对应 three.js isMeshLambertMaterial)
pub fn Material::is_lambert(self : Material) -> Bool {
  self.kind == 1
}

///| 是否 Phong(对应 three.js isMeshPhongMaterial)
pub fn Material::is_phong(self : Material) -> Bool {
  self.kind == 2
}

///| 是否受光照(Basic 不受光;Lambert/Phong 受光)
pub fn Material::lit(self : Material) -> Bool {
  self.kind == 1 || self.kind == 2
}
