// A8 公告板精灵/粒子 WGSL 管线:透明混合(alpha blend)、不写深度、
// 双面不剔除。顶点着色器按 uniform 里的公告板轴组装世界坐标:
//   world = center + axis_x * corner_x' + axis_y * corner_y' + axis_z * pos.z
// 精灵路径(center=折入锚点的节点位置,axis_x/y=相机右/上×尺寸,axis_z=0)
// 与粒子路径(positions 已是世界四角:center=0,axis=(1,0,0)/(0,1,0)/(0,0,1))
// 共用同一条管线,仅 uniform 填法不同。

// uniform 布局(160B,偏移与 WGSL struct 逐字段对齐):
//   0   view_proj : mat4x4
//   64  center : vec4(xyz=世界中心,含锚点平移)
//   80  axis_x : vec4(xyz=right*size_x)
//   96  axis_y : vec4(xyz=up*size_y)
//   112 axis_z : vec4(xyz=粒子路径 (0,0,1),精灵路径 (0,0,0))
//   128 params : vec4(x=rotation 弧度(屏面内旋转),y=opacity)
//   144 color  : vec4(rgb=着色,a=opacity,已含材质不透明度)

///|
let sprite_wgsl : String = "struct U {\n" +
  "  view_proj : mat4x4<f32>,\n" +
  "  center : vec4<f32>,\n" +
  "  axis_x : vec4<f32>,\n" +
  "  axis_y : vec4<f32>,\n" +
  "  axis_z : vec4<f32>,\n" +
  "  params : vec4<f32>,\n" +
  "  color : vec4<f32>,\n" +
  "}\n" +
  "@group(0) @binding(0) var<uniform> u : U;\n" +
  "@group(1) @binding(0) var tmap : texture_2d<f32>;\n" +
  "@group(1) @binding(1) var tsamp : sampler;\n" +
  "struct VSOut {\n" +
  "  @builtin(position) p : vec4<f32>,\n" +
  "  @location(0) uv : vec2<f32>,\n" +
  "}\n" +
  "@vertex fn vs_main(@location(0) corner : vec3<f32>,\n" +
  "    @location(1) uv : vec2<f32>) -> VSOut {\n" +
  "  let c = cos(u.params.x);\n" +
  "  let s = sin(u.params.x);\n" +
  "  let rx = corner.x * c - corner.y * s;\n" +
  "  let ry = corner.x * s + corner.y * c;\n" +
  "  let world = u.center.xyz + u.axis_x.xyz * rx + u.axis_y.xyz * ry\n" +
  "    + u.axis_z.xyz * corner.z;\n" +
  "  var o : VSOut;\n" +
  "  o.p = u.view_proj * vec4<f32>(world, 1.0);\n" +
  "  o.uv = uv;\n" +
  "  return o;\n" +
  "}\n" +
  "@fragment fn fs_main(in : VSOut) -> @location(0) vec4<f32> {\n" +
  "  let t = textureSample(tmap, tsamp, in.uv);\n" +
  "  return vec4<f32>(t.rgb * u.color.rgb, t.a * u.color.a);\n" +
  "}\n"

///|
/// uniform 缓冲大小(64 + 6×16)
let sprite_uniform_size : UInt64 = 160UL

///| 创建公告板管线(顶点布局:location0=float32x3 步长 12、

///|
/// location1=float32x2 步长 8;alpha 混合、不写深度、双面)
fn create_sprite_pipeline(
  device : @wgpu_mbt.Device,
  format : @wgpu_mbt.TextureFormat,
  bgl : @wgpu_mbt.BindGroupLayout,
  tex_bgl : @wgpu_mbt.BindGroupLayout,
) -> @wgpu_mbt.RenderPipeline raise Error {
  let vs = device.create_shader_module_wgsl(sprite_wgsl)
  let fs = device.create_shader_module_wgsl(sprite_wgsl)
  let pl = device.create_pipeline_layout_2(bgl, tex_bgl)
  let b = @wgpu_mbt.RenderPipelineDescBuilder::new(vs, layout=pl)
  b.set_fragment_module(fs)
  b.set_entry_points("vs_main", "fs_main")
  b.set_color_target_format(format)
  b.set_topology_u32(@wgpu_mbt.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
  // 公告板按相机轴展开,绕序随旋转语义无意义,不剔除
  b.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_NONE)
  // 透明混合 + 深度测试开/深度写关:被不透明几何遮挡,自身互不穿洞
  b.enable_alpha_blend()
  b.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
    depth_write_enabled=false,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  let _vb = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 0U)
  let _vb2 = b.add_vertex_buffer_layout(8UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 1U)
  let p = b.create_pipeline(device)
  b.free()
  p
}

///| 公告板 uniform 编码:vp 矩阵 + center/axis_x/axis_y/axis_z 三个轴 +

///|
/// params(rotation, opacity)+ color(rgb, a=opacity)
fn sprite_uniform_bytes(
  view_proj : @math3d.Matrix4,
  center : @math3d.Vector3,
  axis_x : @math3d.Vector3,
  axis_y : @math3d.Vector3,
  axis_z : @math3d.Vector3,
  rotation : Double,
  color : @math3d.Color,
  opacity : Double,
) -> Bytes {
  let b : FixedArray[Byte] = FixedArray::make(160, b'0')
  let m = view_proj.e
  for i in 0..<16 {
    write_f32(b, i * 4, m[i])
  }
  write_f32(b, 64, center.x)
  write_f32(b, 68, center.y)
  write_f32(b, 72, center.z)
  write_f32(b, 76, 0.0)
  write_f32(b, 80, axis_x.x)
  write_f32(b, 84, axis_x.y)
  write_f32(b, 88, axis_x.z)
  write_f32(b, 92, 0.0)
  write_f32(b, 96, axis_y.x)
  write_f32(b, 100, axis_y.y)
  write_f32(b, 104, axis_y.z)
  write_f32(b, 108, 0.0)
  write_f32(b, 112, axis_z.x)
  write_f32(b, 116, axis_z.y)
  write_f32(b, 120, axis_z.z)
  write_f32(b, 124, 0.0)
  write_f32(b, 128, rotation)
  write_f32(b, 132, opacity)
  write_f32(b, 136, 0.0)
  write_f32(b, 140, 0.0)
  write_f32(b, 144, color.r)
  write_f32(b, 148, color.g)
  write_f32(b, 152, color.b)
  write_f32(b, 156, opacity)
  to_bytes(b)
}
