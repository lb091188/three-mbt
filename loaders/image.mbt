// 图像字节 → Texture:mizchi/image 解码(JPEG/PNG/BMP)→ RGBA8 紧排
// → TextureSource + CPU mip 链。游戏侧资产是 8 张 JPG 纹理;
// 16 位灰度高程图不走这里(steel-front 迁移仓有专用 PNG16 解码器)。

///| 解码图像字节为纹理。环绕/过滤取 three.js Texture 默认
///| (ClampToEdge + LinearMipmapLinear);重复平铺由调用方设
///| wrap_s/wrap_t=Repeat 与 repeat=(n,m)(对齐 assets.js:79-83 的用法,
///| 游戏侧是 wrapS/wrapT=RepeatWrapping + anisotropy=8)。
pub fn load_texture_image_bytes(bytes : Bytes) -> @core.Texture raise Error {
  let img = @image.decode_jpeg(bytes) catch {
    _ => @image.decode_png(bytes) catch {
        e => raise Failure("load_texture: JPEG/PNG 解码均失败: \{e}")
      }
  }
  let t = @core.Texture::from_rgba(img.width, img.height, img.data)
  t.color_space = @core.ColorSpace::SRGB
  t
}

///| JPEG 专用(避免先试 PNG 的无谓解码尝试)
pub fn load_texture_jpeg_bytes(bytes : Bytes) -> @core.Texture raise Error {
  let img = @image.decode_jpeg(bytes) catch {
    e => raise Failure("load_texture_jpeg: \{e}")
  }
  let t = @core.Texture::from_rgba(img.width, img.height, img.data)
  t.color_space = @core.ColorSpace::SRGB
  t
}

///| PNG(RGBA8)专用
pub fn load_texture_png_bytes(bytes : Bytes) -> @core.Texture raise Error {
  let img = @image.decode_png(bytes) catch {
    e => raise Failure("load_texture_png: \{e}")
  }
  let t = @core.Texture::from_rgba(img.width, img.height, img.data)
  t.color_space = @core.ColorSpace::SRGB
  t
}
