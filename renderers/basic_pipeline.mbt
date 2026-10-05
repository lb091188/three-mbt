// Basic 材质 WGSL 管线:mvp 变换 + 纯色输出(无光照)。

// uniform 布局:mat4x4(64B) + vec4 颜色(16B) = 80B
let basic_wgsl : String = "struct U { mvp : mat4x4<f32>, color : vec4<f32>, };\n" +
  "@group(0) @binding(0) var<uniform> u : U;\n" +
  "struct VSOut { @builtin(position) p : vec4<f32>, };\n" +
  "@vertex fn vs_main(@location(0) pos : vec3<f32>) -> VSOut {\n" +
  "  var o : VSOut;\n" +
  "  o.p = u.mvp * vec4<f32>(pos, 1.0);\n" +
  "  return o;\n" +
  "}\n" +
  "@fragment fn fs_main(in : VSOut) -> @location(0) vec4<f32> {\n" +
  "  return u.color;\n" +
  "}\n"

///| uniform 缓冲大小(mvp 64 + color 16)
let uniform_size : UInt64 = 80UL

///| 创建 Basic 管线(位置顶点布局:location0 = float32x3,步长 12;
/// layout 必须与 draw 时 set 的 bind group 同源)
fn create_basic_pipeline(
  device : @wgpu_mbt.Device,
  format : @wgpu_mbt.TextureFormat,
  bgl : @wgpu_mbt.BindGroupLayout,
  tex_bgl : @wgpu_mbt.BindGroupLayout,
) -> @wgpu_mbt.RenderPipeline raise Error {
  let vs = device.create_shader_module_wgsl(basic_wgsl)
  let fs = device.create_shader_module_wgsl(basic_wgsl)
  // Basic 不采样贴图,但布局统一挂两组(shader 未引用的组合法),
  /// 两条管线管线布局同构,切换无重排
  let pl = device.create_pipeline_layout_2(bgl, tex_bgl)
  let b = @wgpu_mbt.RenderPipelineDescBuilder::new(vs, layout=pl)
  b.set_fragment_module(fs)
  b.set_entry_points("vs_main", "fs_main")
  b.set_color_target_format(format)
  b.set_topology_u32(@wgpu_mbt.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
  b.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_BACK)
  b.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(
      @wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS,
    ),
    depth_write_enabled=true,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  let _vb = b.add_vertex_buffer_layout(
    12UL,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  b.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X3,
    0UL,
    0U,
  )
  let p = b.create_pipeline(device)
  b.free()
  p
}
