// Lambert/Phong 光照 WGSL 管线:世界空间法线 + 直接光 + Blinn-Phong 高光。
// 光照公式与常数照搬 three.js ShaderChunk:BRDF_Lambert=RECIPROCAL_PI*diffuse、
// BRDF_BlinnPhong(F_Schlick f90=1 / G=0.25 / D=RECIPROCAL_PI*(shininess*0.5+1)*
// pow(dotNH,shininess))、点光 Frostbite 距离衰减 1/max(pow(d,decay),0.01) 且
// cutoff>0 时再乘 pow2(saturate(1-pow4(d/cutoff)));光色=CPU 侧 color*intensity。

// uniform 布局(592B,偏移与 WGSL struct 逐字段对齐):
//   0  mvp : mat4x4(裁剪空间变换)
//   64 model : mat4x4(局部→世界)
//   128 normal_mat : mat4x4(model 逆转置,取左上 3x3 变换法线)
//   192 cam_pos : vec4(世界空间相机位置)
//   208 color : vec4(漫反射色,alpha 恒 1)
//   224 emissive : vec4(自发光)
//   240 specular : vec4(Phong 高光色)
//   256 mat_params : vec4(x=shininess,y=材质 kind:1=Lambert、2=Phong)
//   272 ambient : vec4(rgb=光色*强度,w=是否启用)
//   288 dir_dir : vec4(xyz=表面指向光源的单位向量,w=是否启用)
//   304 dir_color : vec4(rgb=光色*强度)
//   320 point_pos : vec4(xyz=世界空间发光位置,w=是否启用)
//   336 point_color : vec4(rgb=光色*强度)
//   352 point_params : vec4(x=distance,y=decay)
//   368 uv_tr : vec4(xy=repeat,zw=offset;A1 纹理管线)
//   384 hemi_sky : vec4(rgb=天色*强度,w=启用)
//   400 hemi_ground : vec4(rgb=地色*强度)
//   416 view : mat4x4(雾深换算)
//   480 fog_params : vec4(x=density,y=near,z=far,w=0无/1线性/2指数)
//   496 fog_color : vec4
//   512 light_matrix : mat4x4(阴影矩阵=正交投影×阴影视图;A5)
//   576 shadow_params : vec4(x=bias,y=map_size,z=texel=1/map_size,
//                            w=阴影启用:方向光 cast_shadow 且 mesh receive)

///|
let lit_wgsl : String = "struct U {\n" +
  "  mvp : mat4x4<f32>,\n" +
  "  model : mat4x4<f32>,\n" +
  "  normal_mat : mat4x4<f32>,\n" +
  "  cam_pos : vec4<f32>,\n" +
  "  color : vec4<f32>,\n" +
  "  emissive : vec4<f32>,\n" +
  "  specular : vec4<f32>,\n" +
  "  mat_params : vec4<f32>,\n" +
  "  ambient : vec4<f32>,\n" +
  "  dir_dir : vec4<f32>,\n" +
  "  dir_color : vec4<f32>,\n" +
  "  point_pos : vec4<f32>,\n" +
  "  point_color : vec4<f32>,\n" +
  "  point_params : vec4<f32>,\n" +
  "  uv_tr : vec4<f32>,\n" +
  "  hemi_sky : vec4<f32>,\n" +
  "  hemi_ground : vec4<f32>,\n" +
  "  view : mat4x4<f32>,\n" +
  "  fog_params : vec4<f32>,\n" +
  "  fog_color : vec4<f32>,\n" +
  "  light_matrix : mat4x4<f32>,\n" +
  "  shadow_params : vec4<f32>,\n" +
  "}\n" +
  "@group(0) @binding(0) var<uniform> u : U;\n" +
  "@group(1) @binding(0) var tmap : texture_2d<f32>;\n" +
  "@group(1) @binding(1) var tsamp : sampler;\n" +
  "@group(2) @binding(0) var tshadow : texture_depth_2d;\n" +
  "@group(2) @binding(1) var scompare : sampler_comparison;\n" +
  "const RECIPROCAL_PI : f32 = 0.3183098861837907;\n" +
  "fn f_schlick(f0 : vec3<f32>, dot_vh : f32) -> vec3<f32> {\n" +
  "  let fresnel = exp2((-5.55473 * dot_vh - 6.98316) * dot_vh);\n" +
  "  return f0 * (1.0 - fresnel) + fresnel;\n" +
  "}\n" +
  "fn brdf_blinn_phong(light_dir : vec3<f32>, view_dir : vec3<f32>,\n" +
  "    normal : vec3<f32>, specular_color : vec3<f32>, shininess : f32) -> vec3<f32> {\n" +
  "  let half_dir = normalize(light_dir + view_dir);\n" +
  "  let dot_nh = clamp(dot(normal, half_dir), 0.0, 1.0);\n" +
  "  let dot_vh = clamp(dot(view_dir, half_dir), 0.0, 1.0);\n" +
  "  let f = f_schlick(specular_color, dot_vh);\n" +
  "  let g = 0.25;\n" +
  "  let d = RECIPROCAL_PI * (shininess * 0.5 + 1.0) * pow(dot_nh, shininess);\n" +
  "  return f * (g * d);\n" +
  "}\n" +
  "fn get_distance_attenuation(light_dist : f32, cutoff : f32, decay : f32) -> f32 {\n" +
  "  var falloff = 1.0 / max(pow(light_dist, decay), 0.01);\n" +
  "  if (cutoff > 0.0) {\n" +
  "    let s = clamp(1.0 - pow(light_dist / cutoff, 4.0), 0.0, 1.0);\n" +
  "    falloff = falloff * s * s;\n" +
  "  }\n" +
  "  return falloff;\n" +
  "}\n" +
  "// A5 方向光阴影:PCF 2x2(四次 texel 偏移硬比较取均值)。uv 由阴影矩阵\n" +
  "// 裁剪坐标映射——WebGPU 帧缓冲 y 向下,v 取 0.5-0.5*y;出界不遮挡。\n" +
  "// 禁用(shadow_params.w=0)直接返 1,不触碰绑定纹理。\n" +
  "fn get_shadow(world_pos : vec3<f32>) -> f32 {\n" +
  "  if (u.shadow_params.w < 0.5) { return 1.0; }\n" +
  "  let sp = u.light_matrix * vec4<f32>(world_pos, 1.0);\n" +
  "  let uv = vec2<f32>(0.5 + 0.5 * sp.x / sp.w, 0.5 - 0.5 * sp.y / sp.w);\n" +
  "  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { return 1.0; }\n" +
  "  let refd = sp.z / sp.w - u.shadow_params.x;\n" +
  "  let t = u.shadow_params.z;\n" +
  "  var s = textureSampleCompare(tshadow, scompare, uv + vec2<f32>(-t, -t), refd);\n" +
  "  s = s + textureSampleCompare(tshadow, scompare, uv + vec2<f32>(t, -t), refd);\n" +
  "  s = s + textureSampleCompare(tshadow, scompare, uv + vec2<f32>(-t, t), refd);\n" +
  "  s = s + textureSampleCompare(tshadow, scompare, uv + vec2<f32>(t, t), refd);\n" +
  "  return s * 0.25;\n" +
  "}\n" +
  "struct VSOut {\n" +
  "  @builtin(position) pos : vec4<f32>,\n" +
  "  @location(0) world_pos : vec3<f32>,\n" +
  "  @location(1) world_normal : vec3<f32>,\n" +
  "  @location(2) uv : vec2<f32>,\n" +
  "  @location(3) vcolor : vec3<f32>,\n" +
  "  @location(4) fog_depth : f32,\n" +
  "}\n" +
  "@vertex fn vs_main(@location(0) obj_pos : vec3<f32>,\n" +
  "    @location(1) obj_normal : vec3<f32>,\n" +
  "    @location(2) obj_uv : vec2<f32>,\n" +
  "    @location(3) obj_color : vec3<f32>) -> VSOut {\n" +
  "  var o : VSOut;\n" +
  "  o.pos = u.mvp * vec4<f32>(obj_pos, 1.0);\n" +
  "  o.world_pos = (u.model * vec4<f32>(obj_pos, 1.0)).xyz;\n" +
  "  let nm = mat3x3<f32>(u.normal_mat[0].xyz, u.normal_mat[1].xyz,\n" +
  "    u.normal_mat[2].xyz);\n" +
  "  o.world_normal = nm * obj_normal;\n" +
  "  o.uv = obj_uv;\n" +
  "  o.vcolor = obj_color;\n" +
  "  let wp = u.model * vec4<f32>(obj_pos, 1.0);\n" +
  "  o.fog_depth = -(u.view * wp).z;\n" +
  "  return o;\n" +
  "}\n" +
  "@fragment fn fs_main(in : VSOut) -> @location(0) vec4<f32> {\n" +
  "  let n = normalize(in.world_normal);\n" +
  "  let v = normalize(u.cam_pos.xyz - in.world_pos);\n" +
  "  var diffuse_irradiance = u.ambient.xyz;\n" +
  "  // 半球光:世界法线 y 分量在地/天色间混合(n.y∈[-1,1] → mix [0,1])\n" +
  "  if (u.hemi_sky.w > 0.5) {\n" +
  "    let h = clamp(0.5 + 0.5 * n.y, 0.0, 1.0);\n" +
  "    diffuse_irradiance = diffuse_irradiance +\n" +
  "      mix(u.hemi_ground.xyz, u.hemi_sky.xyz, vec3<f32>(h));\n" +
  "  }\n" +
  "  var specular_sum = vec3<f32>(0.0);\n" +
  "  let is_phong = u.mat_params.y > 1.5;\n" +
  "  let shininess = u.mat_params.x;\n" +
  "  if (u.dir_dir.w > 0.5) {\n" +
  "    // 直照光受阴影遮蔽(three.js 直照光 color *= getShadow 同语义;\n" +
  "    // 环境光/半球光/点光不受此阴影)\n" +
  "    let shadow_f = get_shadow(in.world_pos);\n" +
  "    let l = normalize(u.dir_dir.xyz);\n" +
  "    let irradiance = clamp(dot(n, l), 0.0, 1.0) * u.dir_color.xyz * shadow_f;\n" +
  "    diffuse_irradiance = diffuse_irradiance + irradiance;\n" +
  "    if (is_phong) {\n" +
  "      specular_sum = specular_sum + irradiance *\n" +
  "        brdf_blinn_phong(l, v, n, u.specular.xyz, shininess);\n" +
  "    }\n" +
  "  }\n" +
  "  if (u.point_pos.w > 0.5) {\n" +
  "    let to_light = u.point_pos.xyz - in.world_pos;\n" +
  "    let light_dist = length(to_light);\n" +
  "    let l = to_light / max(light_dist, 0.000001);\n" +
  "    let irradiance = clamp(dot(n, l), 0.0, 1.0) * u.point_color.xyz *\n" +
  "      get_distance_attenuation(light_dist, u.point_params.x, u.point_params.y);\n" +
  "    diffuse_irradiance = diffuse_irradiance + irradiance;\n" +
  "    if (is_phong) {\n" +
  "      specular_sum = specular_sum + irradiance *\n" +
  "        brdf_blinn_phong(l, v, n, u.specular.xyz, shininess);\n" +
  "    }\n" +
  "  }\n" +
  "  var base_color = u.color.xyz * in.vcolor;\n" +
  "  let uv2 = in.uv * u.uv_tr.xy + u.uv_tr.zw;\n" +
  "  let ts = textureSample(tmap, tsamp, uv2);\n" +
  "  base_color = base_color * ts.xyz;\n" +
  "  var rgb = u.emissive.xyz + diffuse_irradiance * RECIPROCAL_PI * base_color;\n" +
  "  rgb = rgb + specular_sum;\n" +
  "  return vec4<f32>(rgb, u.color.a);\n" +
  "}\n"

///| 光照 uniform 缓冲大小(4 mat4 + 18 vec4 = 512B + 阴影段 80B = 592B;

///|
/// view 用于雾深,雾参数 w=0无/1线性/2指数,阴影矩阵/参数 A5)
let lit_uniform_size : UInt64 = 592UL

///| 创建光照管线(顶点布局:双缓冲——slot0 位置、slot1 法线,各 float32x3 步长 12;

///| BufferGeometry 的 positions/normals 本就是两个独立数组,直接分 buffer 上传

///| 免交错重组;layout 与 draw 时 set 的 bind group 同源。三组布局:

///|
/// group0 uniform、group1 贴图、group2 阴影贴图+比较采样器 A5)
fn create_lit_pipeline(
  device : @wgpu_mbt.Device,
  format : @wgpu_mbt.TextureFormat,
  bgl : @wgpu_mbt.BindGroupLayout,
  tex_bgl : @wgpu_mbt.BindGroupLayout,
  shadow_bgl : @wgpu_mbt.BindGroupLayout,
) -> @wgpu_mbt.RenderPipeline raise Error {
  let vs = device.create_shader_module_wgsl(lit_wgsl)
  let fs = device.create_shader_module_wgsl(lit_wgsl)
  let pl = device.create_pipeline_layout_many([bgl, tex_bgl, shadow_bgl])
  let b = @wgpu_mbt.RenderPipelineDescBuilder::new(vs, layout=pl)
  b.set_fragment_module(fs)
  b.set_entry_points("vs_main", "fs_main")
  b.set_color_target_format(format)
  b.set_topology_u32(@wgpu_mbt.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
  b.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_BACK)
  b.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
    depth_write_enabled=true,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  let _vb0 = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 0U)
  let _vb1 = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 1U)
  // slot2 uv(float32x2)、slot3 顶点色(float32x3)——几何缺属性时上传层补默认值
  let _vb2 = b.add_vertex_buffer_layout(8UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 2U)
  let _vb3 = b.add_vertex_buffer_layout(12UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  b.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 0UL, 3U)
  let p = b.create_pipeline(device)
  b.free()
  p
}

///| 光照 uniform 编码:变换矩阵×4 + 相机位置 + 材质 + 场景光源集合 + 阴影。

///| shadow_matrix 在方向光 cast_shadow 时为 proj×view(渲染层每帧算一次);

///|
/// receive_shadow 为本 mesh 的接收开关,两者皆真才写入启用段
fn lit_uniform_bytes(
  mvp : @math3d.Matrix4,
  model : @math3d.Matrix4,
  normal_mat : @math3d.Matrix4,
  view : @math3d.Matrix4,
  cam_pos : @math3d.Vector3,
  material : @core.Material,
  lights : @core.SceneLights,
  fog : @core.Fog?,
  shadow_matrix : @math3d.Matrix4,
  receive_shadow : Bool,
) -> Bytes {
  // 零初始化:未启用的灯光段保持 0(enable 位与颜色皆零)
  let b : FixedArray[Byte] = FixedArray::make(592, b'\x00')
  write_matrix4(b, 0, mvp)
  write_matrix4(b, 64, model)
  write_matrix4(b, 128, normal_mat)
  write_f32(b, 192, cam_pos.x)
  write_f32(b, 196, cam_pos.y)
  write_f32(b, 200, cam_pos.z)
  write_f32(b, 204, 0.0)
  write_f32(b, 208, material.color.r)
  write_f32(b, 212, material.color.g)
  write_f32(b, 216, material.color.b)
  write_f32(b, 220, 1.0)
  write_f32(b, 224, material.emissive.r)
  write_f32(b, 228, material.emissive.g)
  write_f32(b, 232, material.emissive.b)
  write_f32(b, 236, 0.0)
  write_f32(b, 240, material.specular.r)
  write_f32(b, 244, material.specular.g)
  write_f32(b, 248, material.specular.b)
  write_f32(b, 252, 0.0)
  write_f32(b, 256, material.shininess)
  write_f32(b, 260, Int::to_double(material.kind))
  // mat_params.z = 材质是否受雾(1/0)
  write_f32(b, 264, if material.fog { 1.0 } else { 0.0 })
  write_f32(b, 268, 0.0)
  match lights.ambient {
    Some(a) => {
      write_f32(b, 272, a.color.r * a.intensity)
      write_f32(b, 276, a.color.g * a.intensity)
      write_f32(b, 280, a.color.b * a.intensity)
      write_f32(b, 284, 1.0)
    }
    None => ()
  }
  match lights.directional {
    Some(d) => {
      write_f32(b, 288, d.direction.x)
      write_f32(b, 292, d.direction.y)
      write_f32(b, 296, d.direction.z)
      write_f32(b, 300, 1.0)
      write_f32(b, 304, d.color.r * d.intensity)
      write_f32(b, 308, d.color.g * d.intensity)
      write_f32(b, 312, d.color.b * d.intensity)
      write_f32(b, 316, 0.0)
    }
    None => ()
  }
  match lights.point {
    Some(p) => {
      write_f32(b, 320, p.position.x)
      write_f32(b, 324, p.position.y)
      write_f32(b, 328, p.position.z)
      write_f32(b, 332, 1.0)
      write_f32(b, 336, p.color.r * p.intensity)
      write_f32(b, 340, p.color.g * p.intensity)
      write_f32(b, 344, p.color.b * p.intensity)
      write_f32(b, 348, 0.0)
      write_f32(b, 352, p.distance)
      write_f32(b, 356, p.decay)
      write_f32(b, 360, 0.0)
      write_f32(b, 364, 0.0)
    }
    None => ()
  }
  // uv_tr:repeat.xy + offset.xy(无贴图时 1,1,0,0 —— 采样白纹理结果不变)
  let (ru, rv, ou, ov) = match material.map {
    Some(t) => (t.repeat.x, t.repeat.y, t.offset.x, t.offset.y)
    None => (1.0, 1.0, 0.0, 0.0)
  }
  write_f32(b, 368, ru)
  write_f32(b, 372, rv)
  write_f32(b, 376, ou)
  write_f32(b, 380, ov)
  // 半球光(384/400:w=启用位;颜色预乘强度)
  match lights.hemisphere {
    Some(h) => {
      write_f32(b, 384, h.sky_color.r)
      write_f32(b, 388, h.sky_color.g)
      write_f32(b, 392, h.sky_color.b)
      write_f32(b, 396, 1.0)
      write_f32(b, 400, h.ground_color.r)
      write_f32(b, 404, h.ground_color.g)
      write_f32(b, 408, h.ground_color.b)
      write_f32(b, 412, 0.0)
    }
    None => ()
  }
  // view 矩阵(416,雾深换算用)与雾参数(480)/雾色(496)
  write_matrix4(b, 416, view)
  match fog {
    Some(f) => {
      write_f32(b, 480, f.density)
      write_f32(b, 484, f.near)
      write_f32(b, 488, f.far)
      // w:0=无雾、1=线性、2=指数(与 WGSL select 分支对应)
      write_f32(b, 492, Int::to_double(f.kind + 1))
      write_f32(b, 496, f.color.r)
      write_f32(b, 500, f.color.g)
      write_f32(b, 504, f.color.b)
      write_f32(b, 508, 0.0)
    }
    None => ()
  }
  // 阴影(512/576):矩阵 + x=bias、y=map_size、z=texel、w=启用
  match lights.directional {
    Some(d) if d.cast_shadow && receive_shadow => {
      write_matrix4(b, 512, shadow_matrix)
      write_f32(b, 576, d.shadow.bias)
      write_f32(b, 580, Int::to_double(d.shadow.map_size))
      write_f32(
        b,
        584,
        1.0 /
        Double::from_int(
          if d.shadow.map_size < 1 {
            1
          } else {
            d.shadow.map_size
          },
        ),
      )
      write_f32(b, 588, 1.0)
    }
    _ => ()
  }
  to_bytes(b)
}

///|
/// 单个 mat4 写入缓冲指定偏移(16 元素连续)
fn write_matrix4(
  buf : FixedArray[Byte],
  off : Int,
  m : @math3d.Matrix4,
) -> Unit {
  for i in 0..<16 {
    write_f32(buf, off + i * 4, m.e[i])
  }
}

///|
/// 把环境光挂到场景光源集合(光源移动/变色后需重挂)
pub fn attach_ambient_light(
  scene : @core.Scene,
  light : @lights.AmbientLight,
) -> Unit {
  scene.lights.ambient = Some({
    color: light.color,
    intensity: light.intensity,
  })
}

///| 把方向光挂到场景光源集合:入射方向 = 光源位置 - target 位置的归一化

///|(three.js 方向光 uniform 同式;target 变换后需重挂)。阴影参数一并

///| 挂接:position=光源世界位置(阴影相机视点)、cast_shadow 开关与

///|
/// shadow 结构体引用(后续改 map_size/视锥即时生效,同 three.js 活引用)
pub fn attach_directional_light(
  scene : @core.Scene,
  light : @lights.DirectionalLight,
) -> Unit {
  let from = light.obj.world_position()
  let to = light.target.world_position()
  scene.lights.directional = Some({
    direction: from.sub(to).normalize(),
    color: light.color,
    intensity: light.intensity,
    position: from,
    cast_shadow: light.cast_shadow,
    shadow: light.shadow,
  })
}

///|
/// 把半球光挂到场景光源集合(颜色预乘强度;换色后需重挂)
pub fn attach_hemisphere_light(
  scene : @core.Scene,
  light : @lights.HemisphereLight,
) -> Unit {
  let i = light.intensity
  scene.lights.hemisphere = Some({
    sky_color: @math3d.Color::new(
      light.color.r * i,
      light.color.g * i,
      light.color.b * i,
    ),
    ground_color: @math3d.Color::new(
      light.ground_color.r * i,
      light.ground_color.g * i,
      light.ground_color.b * i,
    ),
  })
}

///|
/// 把点光源挂到场景光源集合(光源移动后需重挂)
pub fn attach_point_light(
  scene : @core.Scene,
  light : @lights.PointLight,
) -> Unit {
  scene.lights.point = Some({
    position: light.obj.world_position(),
    color: light.color,
    intensity: light.intensity,
    distance: light.distance,
    decay: light.decay,
  })
}
