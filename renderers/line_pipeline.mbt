// Line 管线(A7):LineBasic 走 basic 族 uniform 布局(mvp 64B + color 16B),
// 顶点布局两槽 —— location0 位置、location1 顶点色(几何缺省补白,乘法恒等,
// 与 lit 管线补默认顶点色同策略)。拓扑由调用方定:LINE_STRIP(Line)/
// LINE_LIST(LineSegments);线无面向,不剔除;深度测试照常参与。

// uniform 布局与 basic 同构:mat4x4(64B) + vec4 颜色(16B) = 80B;
// 片元色 = 主色 rgb × 顶点色(无顶点色时顶点色槽补白 → 恒等于主色)

///|
let line_wgsl : String = "struct U { mvp : mat4x4<f32>, color : vec4<f32>, };\n" +
  "@group(0) @binding(0) var<uniform> u : U;\n" +
  "struct VSOut { @builtin(position) p : vec4<f32>, @location(0) col : vec3<f32>, };\n" +
  "@vertex fn vs_main(@location(0) pos : vec3<f32>, @location(1) vcol : vec3<f32>) -> VSOut {\n" +
  "  var o : VSOut;\n" +
  "  o.p = u.mvp * vec4<f32>(pos, 1.0);\n" +
  "  o.col = vcol;\n" +
  "  return o;\n" +
  "}\n" +
  "@fragment fn fs_main(in : VSOut) -> @location(0) vec4<f32> {\n" +
  "  return vec4<f32>(u.color.rgb * in.col, u.color.a);\n" +
  "}\n"

///| 创建 Line 管线(topology_u32:PRIMITIVE_TOPOLOGY_LINE_STRIP / LINE_LIST;

///|
/// layout 与 basic/lit 同构双 BGL,group(1) 绑白占位不采样)
fn create_line_pipeline(
  device : @wgpu_mbt.Device,
  format : @wgpu_mbt.TextureFormat,
  bgl : @wgpu_mbt.BindGroupLayout,
  tex_bgl : @wgpu_mbt.BindGroupLayout,
  topology_u32 : UInt,
) -> @wgpu_mbt.RenderPipeline raise Error {
  let vs = device.create_shader_module_wgsl(line_wgsl)
  let fs = device.create_shader_module_wgsl(line_wgsl)
  let pl = device.create_pipeline_layout_2(bgl, tex_bgl)
  let b = @wgpu_mbt.RenderPipelineDescBuilder::new(vs, layout=pl)
  b.set_fragment_module(fs)
  b.set_entry_points("vs_main", "fs_main")
  b.set_color_target_format(format)
  b.set_topology_u32(topology_u32)
  // 线无几何面向,双面皆可见
  b.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_NONE)
  b.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
    depth_write_enabled=true,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  // 两槽均为 float32x3 步长 12:位置(location0)与顶点色(location1)
  let _vb0 = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 0U)
  let _vb1 = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 1U)
  let p = b.create_pipeline(device)
  b.free()
  p
}

///| 线顶点色缓冲字节:几何 colors 长度与顶点数×3 匹配 → 原样上传;

///|
/// 否则补 f32 白(1,1,1),乘主色恒等 —— 顶点色"可选"的缺省路径
fn line_color_bytes(geometry : @core.BufferGeometry) -> Bytes {
  let vcount = geometry.vertex_count()
  if geometry.colors.length() == vcount * 3 {
    f32_array_bytes(geometry.colors)
  } else {
    white_f32_bytes(vcount * 3)
  }
}

///|
/// 单顶点 12 字节(f32 xyz 小端;update_vertex 局部刷新用)
fn f32x3_bytes(x : Double, y : Double, z : Double) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(12, b'0')
  write_f32(b, 0, x)
  write_f32(b, 4, y)
  write_f32(b, 8, z)
  to_bytes(b)
}
