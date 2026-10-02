// three.js Texture 迁移:数据层(环绕/过滤采样参数、UV 平铺与偏移、色彩空间标注)。
// 图像数据引用(three.js source/image)、mipmaps 与上传版本(version/needsUpdate)
// 随图像加载层批次补齐,本文件先落采样与 UV 变换的源数据。

///| 纹理环绕方式(three.js Wrapping 常数,wrap_s/wrap_t 共用同一族)
pub(all) enum Wrapping {
  /// 无限重复(RepeatWrapping=1000)
  Repeat
  /// 边缘像素拉伸到边界(ClampToEdgeWrapping=1001)
  ClampToEdge
  /// 无限重复且逐次镜像(MirroredRepeatWrapping=1002)
  MirroredRepeat
} derive(Debug)

///| 纹理采样过滤器(three.js Filter 常数,mag_filter/min_filter 共用同一族)
pub(all) enum TextureFilter {
  /// 就近采样(NearestFilter=1003)
  Nearest
  /// 就近选 mip 后就近采样(NearestMipmapNearestFilter=1004)
  NearestMipmapNearest
  /// 相邻两个 mip 各自就近采样后加权(NearestMipmapLinearFilter=1005)
  NearestMipmapLinear
  /// 四 texel 加权平均(LinearFilter=1006)
  Linear
  /// 就近选 mip 后线性采样(LinearMipmapNearestFilter=1007)
  LinearMipmapNearest
  /// 相邻两个 mip 各自线性采样后加权(LinearMipmapLinearFilter=1008)
  LinearMipmapLinear
} derive(Debug)

///| 纹理色彩空间标注(three.js 色彩空间字符串常数)
pub(all) enum ColorSpace {
  /// 无色彩空间(NoColorSpace="")
  No
  /// sRGB(SRGBColorSpace="srgb")
  SRGB
  /// 线性 sRGB(LinearSRGBColorSpace="srgb-linear")
  LinearSRGB
} derive(Debug)

pub extend TextureFilter with Debug::{to_repr}

pub extend ColorSpace with Debug::{to_repr}

pub extend Wrapping with Debug::{to_repr}

///| three.js 常数值:Repeat=1000、ClampToEdge=1001、MirroredRepeat=1002
pub fn Wrapping::to_int(self : Wrapping) -> Int {
  match self {
    Repeat => 1000
    ClampToEdge => 1001
    MirroredRepeat => 1002
  }
}

///| three.js 常数值:Nearest=1003 … LinearMipmapLinear=1008
pub fn TextureFilter::to_int(self : TextureFilter) -> Int {
  match self {
    Nearest => 1003
    NearestMipmapNearest => 1004
    NearestMipmapLinear => 1005
    Linear => 1006
    LinearMipmapNearest => 1007
    LinearMipmapLinear => 1008
  }
}

///| three.js 字符串常数:No=""、SRGB="srgb"、LinearSRGB="srgb-linear"
pub fn ColorSpace::to_string(self : ColorSpace) -> String {
  match self {
    No => ""
    SRGB => "srgb"
    LinearSRGB => "srgb-linear"
  }
}

///| 纹理采样与 UV 变换参数(数据层)
pub(all) struct Texture {
  /// U 方向环绕(three.js wrapS)
  mut wrap_s : Wrapping
  /// V 方向环绕(three.js wrapT)
  mut wrap_t : Wrapping
  /// 放大采样:texel 覆盖多于一个像素(three.js magFilter)
  mut mag_filter : TextureFilter
  /// 缩小采样:texel 覆盖不足一个像素(three.js minFilter)
  mut min_filter : TextureFilter
  /// UV 方向重复次数(three.js repeat;某方向 >1 时该方向环绕需为 Repeat/MirroredRepeat)
  mut repeat : @math3d.Vector2
  /// UV 方向偏移(three.js offset,典型范围 0..1)
  mut offset : @math3d.Vector2
  /// 色彩空间标注:含颜色数据的纹理应标 SRGB 或 LinearSRGB(three.js colorSpace)
  mut color_space : ColorSpace
}

///| 构造(默认值对齐 three.js Texture 构造器:
/// wrapS=wrapT=ClampToEdgeWrapping、magFilter=LinearFilter、
/// minFilter=LinearMipmapLinearFilter、repeat=(1,1)、offset=(0,0)、
/// colorSpace=NoColorSpace)
pub fn Texture::new() -> Texture {
  {
    wrap_s: ClampToEdge,
    wrap_t: ClampToEdge,
    mag_filter: Linear,
    min_filter: LinearMipmapLinear,
    repeat: @math3d.Vector2::new(1.0, 1.0),
    offset: @math3d.Vector2::zero(),
    color_space: No,
  }
}
