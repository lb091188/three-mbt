// three.js 材质迁移:Basic(纯色)与受光照的 Lambert/Phong;
// A8 补公告板精灵(kind 3)与粒子(kind 4)两个透明材质标签;
// A7 补线基础材质 LineBasic(kind 5,避让 A8 占用的 3/4)。

///|
/// 材质(Basic/LineBasic 不受光照;Lambert/Phong 参与光照;Sprite/Particle 走
/// 公告板透明管线,渲染层按 kind 分派)
pub(all) struct Material {
  /// 类型标签:0=Basic、1=Lambert、2=Phong、3=Sprite、4=Particle、5=LineBasic
  kind : Int
  /// 主色(漫反射;Sprite/Particle 为着色乘到贴图上)
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
  /// 不透明度(three.js material.opacity,0..1;仅 Sprite/Particle 消费,
  /// 与贴图 alpha 相乘后输出)
  mut opacity : Double
  /// 精灵锚点(three.js SpriteMaterial.center,0..1;默认 (0.5,0.5)=几何中心
  /// 对齐节点位置,(0,0)=左下角对齐。仅 kind=3 消费)
  mut center : @math3d.Vector2
  /// 精灵屏面内旋转(弧度,three.js SpriteMaterial.rotation;仅 kind=3
  /// 消费,着色器侧对四角偏移旋转)
  mut rotation : Double
}

///|
/// Basic 材质(不受光照的纯色)
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
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///|
/// LineBasic 材质(three.js LineBasicMaterial:线的基础不受光材质;
/// 几何 colors 顶点色存在时乘进主色,与 lit 管线同一顶点色语义)
pub fn Material::line_basic(color : @math3d.Color) -> Material {
  {
    kind: 5,
    color,
    emissive: @math3d.Color::black(),
    specular: @math3d.Color::black(),
    shininess: 30.0,
    map: None,
    vertex_colors: false,
    fog: true,
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///| Lambert 材质(漫反射受光,无高光;emissive 为自发光色,

///|
/// three.js MeshLambertMaterial 默认 color=白、emissive=黑)
pub fn Material::lambert(
  color : @math3d.Color,
  emissive : @math3d.Color,
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
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///| Phong 材质(Blinn-Phong 高光;three.js MeshPhongMaterial 默认

///|
/// color=白、specular=#111111、shininess=30、emissive=黑)
pub fn Material::phong(
  color : @math3d.Color,
  specular : @math3d.Color,
  shininess : Double,
  emissive : @math3d.Color,
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
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///| 精灵材质(kind=3;three.js SpriteMaterial 子集:color/map/opacity/

///|
/// center/rotation。渲染为始终面向相机的四边形,透明混合、不写深度)
pub fn Material::sprite(color : @math3d.Color) -> Material {
  {
    kind: 3,
    color,
    emissive: @math3d.Color::black(),
    specular: @math3d.Color::black(),
    shininess: 30.0,
    map: None,
    vertex_colors: false,
    fog: false,
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///| 粒子材质(kind=4;几何位置由粒子系统 CPU 逐帧写入世界空间四角,

///|
/// 渲染同精灵管线:透明混合、不写深度)
pub fn Material::particle(color : @math3d.Color) -> Material {
  {
    kind: 4,
    color,
    emissive: @math3d.Color::black(),
    specular: @math3d.Color::black(),
    shininess: 30.0,
    map: None,
    vertex_colors: false,
    fog: false,
    opacity: 1.0,
    center: @math3d.Vector2::new(0.5, 0.5),
    rotation: 0.0,
  }
}

///|
/// 是否 Basic(对应 three.js isMeshBasicMaterial)
pub fn Material::is_basic(self : Material) -> Bool {
  self.kind == 0
}

///|
/// 是否 LineBasic(对应 three.js isLineBasicMaterial)
pub fn Material::is_line_basic(self : Material) -> Bool {
  self.kind == 5
}

///|
/// 是否 Lambert(对应 three.js isMeshLambertMaterial)
pub fn Material::is_lambert(self : Material) -> Bool {
  self.kind == 1
}

///|
/// 是否 Phong(对应 three.js isMeshPhongMaterial)
pub fn Material::is_phong(self : Material) -> Bool {
  self.kind == 2
}

///|
/// 是否精灵(公告板四边形,kind=3)
pub fn Material::is_sprite(self : Material) -> Bool {
  self.kind == 3
}

///|
/// 是否粒子(CPU 动态几何公告板,kind=4)
pub fn Material::is_particle(self : Material) -> Bool {
  self.kind == 4
}

///|
/// 是否走公告板透明管线(Sprite 与 Particle 共用)
pub fn Material::is_billboard(self : Material) -> Bool {
  self.kind == 3 || self.kind == 4
}

///|
/// 是否受光照(Basic/LineBasic 不受光;Lambert/Phong 受光;Sprite/Particle
/// 自发光不参与光照)
pub fn Material::lit(self : Material) -> Bool {
  self.kind == 1 || self.kind == 2
}
