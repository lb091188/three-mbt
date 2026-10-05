// A5 方向光阴影:深度 pass 收集与阴影视锥矩阵(纯函数,GPU 无关)+
// shadow map GPU 资源(深度纹理 + 比较采样器 + 绑定组)。
// three.js 对应:WebGLShadowMap(渲染 castShadow 物体到 light.shadow.map)、
// DirectionalLightShadow.camera 正交视锥、shadow.matrix(bias*proj*view)。
// 本仓 WebGPU 裁剪域 z∈[0,1],uv 映射放片元着色器(x=0.5+0.5*ndc、
// y=0.5-0.5*ndc——WebGPU 帧缓冲 y 向下,NDC +y 在纹理 v=0 一侧),CPU 侧
// 阴影矩阵保持 proj*view 纯变换。

///|
/// 深度 pass 收集:场景中所有投射阴影的可见三角面 mesh 节点
/// (visible 且 cast_shadow 且三角面拓扑且非公告板材质;three.js shadow
/// map 只渲 castShadow 物体。线拓扑(A7)与公告板精灵/粒子(A8)不进
/// 深度 pass —— 阴影管线按三角面光栅化,线/透明板进去会烙出错误阴影)
pub fn collect_shadow_casters(scene : @core.Scene) -> Array[@core.Object3D] {
  let out : Array[@core.Object3D] = []
  scene.root.traverse(fn(o) {
    match o.mesh {
      Some(m) =>
        if o.visible &&
          m.cast_shadow &&
          m.topology == 0 &&
          !m.material.is_billboard() {
          out.push(o)
        }
      None => ()
    }
    true
  })
  out
}

///| 阴影相机视图矩阵:自光源位置看向 position - direction(three.js

///| DirectionalLightShadow.updateMatrices 的 lookAt 同语义,up=(0,1,0);

///| make_look_at 产基向量作列的旋转(局部→世界),视图取其逆再配平移,

///|
/// 与 PerspectiveCamera::view_matrix 的世界矩阵求逆同构)
pub fn shadow_view_matrix(
  light : @core.SceneDirectionalLight,
) -> @math3d.Matrix4 {
  let eye = light.position
  let rot = @math3d.Matrix4::make_look_at(
    eye,
    eye.sub(light.direction),
    @math3d.Vector3::unit_y(),
  )
  rot
  .invert()
  .multiply(@math3d.Matrix4::make_translation(-eye.x, -eye.y, -eye.z))
}

///|
/// 阴影相机正交投影矩阵(light.shadow.camera 视锥;WebGPU 裁剪域 z∈[0,1])
pub fn shadow_projection_matrix(
  light : @core.SceneDirectionalLight,
) -> @math3d.Matrix4 {
  let c = light.shadow.camera
  @math3d.Matrix4::make_orthographic(
    c.left,
    c.right,
    c.top,
    c.bottom,
    c.near,
    c.far,
  )
}

///| 阴影矩阵 = 正交投影 × 阴影视图(片元着色器用 world_pos 求阴影贴图

///|
/// 坐标;uv 偏置在 shader 内做)
pub fn shadow_light_matrix(
  light : @core.SceneDirectionalLight,
) -> @math3d.Matrix4 {
  shadow_projection_matrix(light).multiply(shadow_view_matrix(light))
}

///|
/// 一份 shadow map 的 GPU 资源(深度纹理 + 视图 + group(2) 绑定组)
struct GpuShadowMap {
  tex : @wgpu_mbt.Texture
  view : @wgpu_mbt.TextureView
  bind_group : @wgpu_mbt.BindGroup
  /// 边长(方形;map_size 变更后重建)
  size : Int
}

///|
/// 建 group(2) 的 BGL:深度纹理(SAMPLE_TYPE_DEPTH)+ 比较采样器
fn create_shadow_bgl(device : @wgpu_mbt.Device) -> @wgpu_mbt.BindGroupLayout {
  let b = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=2UL)
  let _ok_t = b.add_texture(
    0U,
    @wgpu_mbt.ShaderStage::from_u64(@wgpu_mbt.SHADER_STAGE_FRAGMENT),
    @wgpu_mbt.TEXTURE_SAMPLE_TYPE_DEPTH,
    @wgpu_mbt.TEXTURE_VIEW_DIMENSION_2D,
  )
  let _ok_s = b.add_sampler(
    1U,
    @wgpu_mbt.ShaderStage::from_u64(@wgpu_mbt.SHADER_STAGE_FRAGMENT),
    @wgpu_mbt.SAMPLER_BINDING_TYPE_COMPARISON,
  )
  let bgl = b.finish(device)
  b.free()
  bgl
}

///| 深度比较采样器:硬比较(LESS:ref < 存储 → 受照),2x2 PCF 由

///|
/// shader 四次显式偏移采样组成
fn create_shadow_compare_sampler(
  device : @wgpu_mbt.Device,
) -> @wgpu_mbt.Sampler {
  device.create_sampler_u32(
    @wgpu_mbt.ADDRESS_MODE_CLAMP_TO_EDGE,
    @wgpu_mbt.ADDRESS_MODE_CLAMP_TO_EDGE,
    @wgpu_mbt.ADDRESS_MODE_CLAMP_TO_EDGE,
    @wgpu_mbt.FILTER_MODE_NEAREST,
    @wgpu_mbt.FILTER_MODE_NEAREST,
    @wgpu_mbt.MIPMAP_FILTER_MODE_NEAREST,
    compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
}

///| 取或建 shadow map(map_size 变更后自动重建;three.js shadow.map

///|
/// 的 mapSize 变更 dispose 重建同语义)
fn WebGPURenderer::ensure_shadow_map(
  self : WebGPURenderer,
  map_size : Int,
) -> GpuShadowMap {
  match self.shadow_map {
    Some(m) => if m.size == map_size { return m }
    None => ()
  }
  let size = if map_size < 1 { 1 } else { map_size }
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
    @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
  )
  let tex = self.device.create_texture_u32(
    size.reinterpret_as_uint(),
    size.reinterpret_as_uint(),
    1U,
    usage,
    @wgpu_mbt.TextureDimension::from_u32(@wgpu_mbt.TEXTURE_DIMENSION_2D),
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
  )
  let view = tex.create_view()
  let bgb = @wgpu_mbt.BindGroupBuilder::new(max_entries=2UL)
  let _ok_t = bgb.add_texture_view(0U, view)
  let _ok_s = bgb.add_sampler(1U, self.shadow_sampler)
  let bind_group = bgb.finish(self.device, self.shadow_bgl)
  bgb.free()
  let m : GpuShadowMap = { tex, view, bind_group, size, }
  self.shadow_map = Some(m)
  m
}

///| 1×1 占位深度纹理绑定组(方向光不开阴影时 group(2) 的合法占位;

///|
/// shader 以 shadow_params.w=0 短路,永不采样)
fn WebGPURenderer::empty_shadow_bind_group(
  self : WebGPURenderer,
) -> @wgpu_mbt.BindGroup {
  match self.empty_shadow {
    Some(bg) => return bg
    None => ()
  }
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
    @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
  )
  let tex = self.device.create_texture_u32(
    1U,
    1U,
    1U,
    usage,
    @wgpu_mbt.TextureDimension::from_u32(@wgpu_mbt.TEXTURE_DIMENSION_2D),
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
  )
  let view = tex.create_view()
  let bgb = @wgpu_mbt.BindGroupBuilder::new(max_entries=2UL)
  let _ok_t = bgb.add_texture_view(0U, view)
  let _ok_s = bgb.add_sampler(1U, self.shadow_sampler)
  let bind_group = bgb.finish(self.device, self.shadow_bgl)
  bgb.free()
  self.empty_shadow = Some(bind_group)
  bind_group
}
