// three.js 材质迁移:首版 Basic(纯色),Lambert/Phong 随灯光体系批次补齐。

///| 材质(Basic:无光照纯色)
pub(all) struct Material {
  /// 类型标签:0=Basic(后续 1=Lambert、2=Phong)
  kind : Int
  /// 主色
  mut color : @math3d.Color
  /// Phong 高光强度(仅 kind=2 生效)
  mut shininess : Double
}

///| Basic 材质(不受光照)
pub fn Material::basic(color : @math3d.Color) -> Material {
  { kind: 0, color, shininess: 30.0 }
}

///| 是否受光照
pub fn Material::lit(self : Material) -> Bool {
  self.kind != 0
}
