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

///| 纹理图像源:RGBA8 紧排字节(mips[0] 为全尺寸层,逐级减半到 1×1;
///| 行无 padding —— GPU 上传层负责对齐)。CPU 盒式滤波生成 mip 链,
/// 语义对位 three.js WebGL 的 mipmap(斜视角缩小采样防闪烁)。
pub(all) struct TextureSource {
  width : Int
  height : Int
  /// mip 链:至少 1 层(全尺寸);generate_mip_chain 生成
  mips : Array[Bytes]
}

///| 纹理对象 id 计数器(GPU 资源缓存键,对照 Object3D::id 的用途)
let texture_id_counter : Ref[UInt64] = Ref(0UL)

///| 纹理采样与 UV 变换参数(数据层)
pub(all) struct Texture {
  /// 对象 id(构造时分配,GPU 纹理缓存键)
  id : UInt64
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
  /// 各向异性采样倍数(three.js texture.anisotropy,默认 1;斜视角地面用 8)
  mut anisotropy : Int
  /// 像素源(None = 仅采样参数占位,渲染层回退 1×1 白纹理)
  mut source : TextureSource?
}

///| 构造(默认值对齐 three.js Texture 构造器:
/// wrapS=wrapT=ClampToEdgeWrapping、magFilter=LinearFilter、
/// minFilter=LinearMipmapLinearFilter、repeat=(1,1)、offset=(0,0)、
/// colorSpace=NoColorSpace)
pub fn Texture::new() -> Texture {
  texture_id_counter.val = texture_id_counter.val + 1UL
  {
    id: texture_id_counter.val,
    wrap_s: ClampToEdge,
    wrap_t: ClampToEdge,
    mag_filter: Linear,
    min_filter: LinearMipmapLinear,
    repeat: @math3d.Vector2::new(1.0, 1.0),
    offset: @math3d.Vector2::zero(),
    color_space: No,
    anisotropy: 1,
    source: None,
  }
}

///| 从 RGBA8 像素构造带 mip 链的纹理(紧排行,长度须为 w*h*4)
pub fn Texture::from_rgba(width : Int, height : Int, pixels : Bytes) -> Texture {
  let t = Texture::new()
  t.source = Some({
    width,
    height,
    mips: generate_mip_chain(width, height, pixels),
  })
  t
}

///| 重设像素并重建 mip 链(运行时动态改纹理用,如履带滚动偏移走
///| UV offset 无需重建;整图替换才用这个)
pub fn Texture::set_rgba(
  self : Texture,
  width : Int,
  height : Int,
  pixels : Bytes,
) -> Unit {
  self.source = Some({
    width,
    height,
    mips: generate_mip_chain(width, height, pixels),
  })
}

///| CPU 盒式滤波生成 mip 链:每层 2×2 平均到下一层,直到 1×1;
///| 非二次幂尺寸按 floor(w/2)/floor(h/2) 收缩(与 WebGL1 不同,
///| WebGPU/wgpu 允许非二次幂 mip,尺寸取 ceil(w/2) 收缩)。
pub fn generate_mip_chain(
  width : Int,
  height : Int,
  pixels : Bytes,
) -> Array[Bytes] {
  let mips : Array[Bytes] = [pixels]
  let mut w = width
  let mut h = height
  let mut cur = pixels
  while w > 1 || h > 1 {
    let nw = if w > 1 { (w + 1) / 2 } else { 1 }
    let nh = if h > 1 { (h + 1) / 2 } else { 1 }
    let next : FixedArray[Byte] = FixedArray::make(nw * nh * 4, b'\x00')
    for y in 0..<nh {
      for x in 0..<nw {
        // 源 2×2 块(越界 clamp 到边缘)
        let x0 = x * 2
        let y0 = y * 2
        let x1 = if x0 + 1 < w { x0 + 1 } else { x0 }
        let y1 = if y0 + 1 < h { y0 + 1 } else { y0 }
        for c in 0..<4 {
          let s00 = cur[(y0 * w + x0) * 4 + c].to_int() & 0xFF
          let s01 = cur[(y0 * w + x1) * 4 + c].to_int() & 0xFF
          let s10 = cur[(y1 * w + x0) * 4 + c].to_int() & 0xFF
          let s11 = cur[(y1 * w + x1) * 4 + c].to_int() & 0xFF
          next[(y * nw + x) * 4 + c] =
            ((s00 + s01 + s10 + s11 + 2) / 4).to_byte()
        }
      }
    }
    let nb = Bytes::from_array(next[:])
    mips.push(nb)
    cur = nb
    w = nw
    h = nh
  }
  mips
}
