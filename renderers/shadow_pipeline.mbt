// A5 方向光阴影深度管线:mvp(light 投影视图 × model)变换,只写深度
// 不出颜色(three.js shadow map 渲染同构)。正面剔除——与 three.js 默认
// shadowSide=BackSide 等效,闭合几何体自阴影 acne 由"只记录背面深度"天然
// 抑制;平面(地面)朝光面被剔后不写深度,靠 clear 值 1.0 判受照。

// uniform 布局:mat4x4(64B),与 Basic 管线的 mvp 段同构

///|
let shadow_depth_wgsl : String = "struct U { mvp : mat4x4<f32>, };\n" +
  "@group(0) @binding(0) var<uniform> u : U;\n" +
  "@vertex fn vs_main(@location(0) pos : vec3<f32>) -> @builtin(position) vec4<f32> {\n" +
  "  return u.mvp * vec4<f32>(pos, 1.0);\n" +
  "}\n" +
  "@fragment fn fs_main() {\n" +
  "}\n"

///| 创建阴影深度管线(无颜色附着:color_target_count=0;正面剔除;

///|
/// 顶点布局仅位置槽 slot0 float32x3,与 lit/basic 同槽位免重排)
fn create_shadow_pipeline(
  device : @wgpu_mbt.Device,
  bgl : @wgpu_mbt.BindGroupLayout,
) -> @wgpu_mbt.RenderPipeline raise Error {
  let vs = device.create_shader_module_wgsl(shadow_depth_wgsl)
  let fs = device.create_shader_module_wgsl(shadow_depth_wgsl)
  let pl = device.create_pipeline_layout_1(bgl)
  let b = @wgpu_mbt.RenderPipelineDescBuilder::new(vs, layout=pl)
  b.set_fragment_module(fs)
  b.set_entry_points("vs_main", "fs_main")
  b.set_color_target_count(0U)
  b.set_topology_u32(@wgpu_mbt.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
  b.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_FRONT)
  b.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
    depth_write_enabled=true,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  let _vb = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 0U)
  let p = b.create_pipeline(device)
  b.free()
  p
}

///| 阴影深度 pass 的 uniform 编码(仅 mvp,64B;basic/lit 的 ubuf 皆 ≥64B

///|
/// 可复用,免为阴影单独建缓冲)
fn shadow_uniform_bytes(mvp : @math3d.Matrix4) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(64, b'\x00')
  write_matrix4(b, 0, mvp)
  to_bytes(b)
}
