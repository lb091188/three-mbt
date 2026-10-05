// GPU 纹理:Texture(数据层)→ wgpu 纹理(全 mip 链逐层上传)+
// 采样器(环绕/过滤/各向异性按 Texture 参数映射)+ bind group。
// group(1) 布局:binding0 = texture_2d<f32>(FRAGMENT)、binding1 = sampler。
// 无贴图材质绑 1×1 白纹理(white_texture),lit 管线统一走采样路径。

///| 一份纹理的 GPU 资源(tex/sampler 持引用防回收)
pub(all) struct GpuTexture {
  tex : @wgpu_mbt.Texture
  view : @wgpu_mbt.TextureView
  sampler : @wgpu_mbt.Sampler
  bind_group : @wgpu_mbt.BindGroup
}

///| 建 group(1) 的 BGL:纹理 + 采样器(与 uniform 的 group(0) 分离,
///| 管线经 create_pipeline_layout_2 同时挂两组)
fn create_texture_bgl(
  device : @wgpu_mbt.Device,
) -> @wgpu_mbt.BindGroupLayout {
  let b = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=2UL)
  let _ok_t = b.add_texture(
    0U,
    @wgpu_mbt.ShaderStage::from_u64(@wgpu_mbt.SHADER_STAGE_FRAGMENT),
    @wgpu_mbt.TEXTURE_SAMPLE_TYPE_FLOAT,
    @wgpu_mbt.TEXTURE_VIEW_DIMENSION_2D,
  )
  let _ok_s = b.add_sampler(
    1U,
    @wgpu_mbt.ShaderStage::from_u64(@wgpu_mbt.SHADER_STAGE_FRAGMENT),
    @wgpu_mbt.SAMPLER_BINDING_TYPE_FILTERING,
  )
  let bgl = b.finish(device)
  b.free()
  bgl
}

///| Wrapping → wgpu AddressMode 常数
fn address_mode_u32(w : @core.Wrapping) -> UInt {
  match w {
    Repeat => @wgpu_mbt.ADDRESS_MODE_REPEAT
    ClampToEdge => @wgpu_mbt.ADDRESS_MODE_CLAMP_TO_EDGE
    MirroredRepeat => @wgpu_mbt.ADDRESS_MODE_MIRROR_REPEAT
  }
}

///| TextureFilter → 放大/缩小过滤常数(线性族→LINEAR,就近族→NEAREST)
fn filter_mode_u32(f : @core.TextureFilter) -> UInt {
  match f {
    Nearest | NearestMipmapNearest | NearestMipmapLinear => @wgpu_mbt.FILTER_MODE_NEAREST
    Linear | LinearMipmapNearest | LinearMipmapLinear => @wgpu_mbt.FILTER_MODE_LINEAR
  }
}

///| mip 层间过滤:*MipmapLinear → LINEAR,其余 NEAREST
fn mipmap_mode_u32(f : @core.TextureFilter) -> UInt {
  match f {
    LinearMipmapLinear | NearestMipmapLinear => @wgpu_mbt.MIPMAP_FILTER_MODE_LINEAR
    _ => @wgpu_mbt.MIPMAP_FILTER_MODE_NEAREST
  }
}

///| 上传一张纹理:全 mip 链逐层 write_texture,建采样器与 bind group
pub fn WebGPURenderer::ensure_gpu_texture(
  self : WebGPURenderer,
  texture : @core.Texture,
) -> GpuTexture raise Error {
  match self.tex_cache.get(texture.id) {
    Some(g) => return g
    None => ()
  }
  let src = match texture.source {
    Some(s) => s
    None => raise Failure("ensure_gpu_texture: 纹理无像素源(id=\{texture.id})")
  }
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
    @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
  )
  let tex = self.device.create_texture_u32(
    src.width.to_uint(),
    src.height.to_uint(),
    1U,
    usage,
    @wgpu_mbt.TextureDimension::from_u32(
      @wgpu_mbt.TEXTURE_DIMENSION_2D,
    ),
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM),
    mip_level_count=src.mips.length().to_uint(),
  )
  // 逐 mip 上传(上传层自行处理 256B 行对齐)
  let mut w = src.width
  let mut h = src.height
  for i, mip in src.mips {
    self.queue.write_texture_rgba8_2d_mip_layer(
      tex,
      i.to_uint(),
      0U,
      w.to_uint(),
      h.to_uint(),
      mip,
    )
    w = if w > 1 { (w + 1) / 2 } else { 1 }
    h = if h > 1 { (h + 1) / 2 } else { 1 }
  }
  let view = tex.create_view()
  let sampler = self.device.create_sampler_u32(
    address_mode_u32(texture.wrap_s),
    address_mode_u32(texture.wrap_t),
    address_mode_u32(texture.wrap_s),
    filter_mode_u32(texture.mag_filter),
    filter_mode_u32(texture.min_filter),
    mipmap_mode_u32(texture.min_filter),
    max_anisotropy_u32=Int::reinterpret_as_uint(
      if texture.anisotropy < 1 { 1 } else { texture.anisotropy },
    ),
  )
  let bgb = @wgpu_mbt.BindGroupBuilder::new(max_entries=2UL)
  let _ok_t = bgb.add_texture_view(0U, view)
  let _ok_s = bgb.add_sampler(1U, sampler)
  let bind_group = bgb.finish(self.device, self.tex_bgl)
  bgb.free()
  let g : GpuTexture = { tex, view, sampler, bind_group }
  self.tex_cache.set(texture.id, g)
  g
}

///| 1×1 白纹理(无贴图材质的占位:采样恒白,乘法恒等 —— lit 管线统一路径)
pub fn WebGPURenderer::white_texture(self : WebGPURenderer) -> GpuTexture raise Error {
  match self.white {
    Some(g) => return g
    None => ()
  }
  let t = @core.Texture::from_rgba(1, 1, b"\xff\xff\xff\xff")
  t.wrap_s = @core.Wrapping::ClampToEdge
  t.wrap_t = @core.Wrapping::ClampToEdge
  let g = self.ensure_gpu_texture(t)
  self.white = Some(g)
  g
}

///| 纹理像素替换后清缓存(set_rgba 后调;采样参数变更同样需要。
///| 1×1 白纹理不可变,不适用)
pub fn WebGPURenderer::invalidate_texture(
  self : WebGPURenderer,
  texture_id : UInt64,
) -> Unit {
  ignore(self.tex_cache.remove(texture_id))
}
