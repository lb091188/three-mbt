// WebGPURenderer:建在 wgpu_mbt 之上的帧渲染器。
// surface 由宿主窗口的原生句柄创建(X11 与 Win32 路径均已真机趟通)。

///| 单个 mesh 的 GPU 资源(顶点/索引/uniform/绑定组;法线缓冲仅 lit 材质有)
struct GpuMesh {
  vbuf : @wgpu_mbt.Buffer
  /// 法线顶点缓冲(lit 管线 slot1;Basic 材质或无 normals 的几何为 None)
  nbuf : @wgpu_mbt.Buffer?
  /// uv 顶点缓冲(lit 管线 slot2;几何无 uv 时补 (0,0) 默认)
  uvbuf : @wgpu_mbt.Buffer?
  /// 顶点色缓冲(lit 管线 slot3;几何无 colors 时补 (1,1,1) 白)
  cbuf : @wgpu_mbt.Buffer?
  ibuf : @wgpu_mbt.Buffer
  ubuf : @wgpu_mbt.Buffer
  bind_group : @wgpu_mbt.BindGroup
  index_count : UInt
}

///| WebGPU 渲染器
pub(all) struct WebGPURenderer {
  instance : @wgpu_mbt.Instance
  adapter : @wgpu_mbt.Adapter
  device : @wgpu_mbt.Device
  queue : @wgpu_mbt.Queue
  surface : @wgpu_mbt.Surface
  /// group(1) 布局:纹理+采样器(gpu_texture.mbt)
  tex_bgl : @wgpu_mbt.BindGroupLayout
  /// 纹理对象 id → GPU 资源(ensure_gpu_texture 填充)
  mut tex_cache : @hashmap.HashMap[UInt64, GpuTexture]
  /// 1×1 白纹理(无贴图材质占位,惰性建)
  mut white : GpuTexture?
  format : @wgpu_mbt.TextureFormat
  pipeline_basic : @wgpu_mbt.RenderPipeline
  pipeline_lit : @wgpu_mbt.RenderPipeline
  bgl : @wgpu_mbt.BindGroupLayout
  mut width : UInt
  mut height : UInt
  mut depth_view : @wgpu_mbt.TextureView?
  /// 节点 id → GPU 资源缓存(geometry/材质变更后调 invalidate_mesh)
  mut mesh_cache : @hashmap.HashMap[UInt64, GpuMesh]
  /// acquire 首败只警告一次
  mut warned_acquire : Bool
}

///| 从 X11 原生句柄创建渲染器(display/xid 由宿主窗口层换算)
pub fn WebGPURenderer::from_xlib(
  display : UInt64,
  xid : UInt64,
  width : UInt,
  height : UInt,
) -> WebGPURenderer raise Error {
  @wgpu_mbt.set_uncaptured_error_stderr_enabled(true)
  @wgpu_mbt.set_log_callback_stderr_enabled(true)
  let instance = @wgpu_mbt.Instance::create()
  let surface = instance.create_surface_xlib(
    @c.opaque_ptr_from_u64(display),
    xid,
  )
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let format = surface.configure_default(
    adapter,
    device,
    width,
    height,
    @wgpu_mbt.TextureUsage::from_u64(
      @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
    ),
  )
  // uniform BGL:便捷版固定 Fragment 可见性,顶点阶段用 mvp 必须
  // VERTEX|FRAGMENT,走通用 BindGroupLayoutBuilder(Basic/lit 两管线共用)
  let bglb = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=1UL)
  let _bgl_ok = bglb.add_buffer(
    0U,
    @wgpu_mbt.ShaderStage::from_u64(
      @wgpu_mbt.SHADER_STAGE_VERTEX |
      @wgpu_mbt.SHADER_STAGE_FRAGMENT,
    ),
    @wgpu_mbt.BUFFER_BINDING_TYPE_UNIFORM,
  )
  let bgl = bglb.finish(device)
  let tex_bgl = create_texture_bgl(device)
  let pipeline = create_basic_pipeline(device, format, bgl, tex_bgl)
  let lit_pipeline = create_lit_pipeline(device, format, bgl, tex_bgl)
  let r : WebGPURenderer = {
    instance,
    adapter,
    device,
    queue,
    surface,
    format,
    pipeline_basic: pipeline,
    pipeline_lit: lit_pipeline,
    bgl,
    tex_bgl,
    tex_cache: @hashmap.HashMap([], capacity=16),
    white: None,
    width,
    height,
    depth_view: None,
    mesh_cache: @hashmap.HashMap([], capacity=64),
    warned_acquire: false,
  }
  r.rebuild_depth()
  r
}

///| 重建深度附着(resize 后调)
fn WebGPURenderer::rebuild_depth(self : WebGPURenderer) -> Unit {
  let tex = self.device.create_texture_depth24plus_2d(
    self.width,
    self.height,
  )
  self.depth_view = Some(tex.create_view())
}

///| 尺寸变化:重配 surface 与深度附着(格式沿用)
pub fn WebGPURenderer::resize(
  self : WebGPURenderer,
  width : UInt,
  height : UInt,
) -> Unit {
  if width == 0U || height == 0U {
    return
  }
  if width == self.width && height == self.height {
    return
  }
  self.width = width
  self.height = height
  self.warned_acquire = false
  let _ = self.surface.configure_default(
    self.adapter,
    self.device,
    width,
    height,
    @wgpu_mbt.TextureUsage::from_u64(
      @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
    ),
  )
  self.rebuild_depth()
}

///| geometry/材质变更后清缓存(节点 id;材质 kind 变更同样需失效重建)
pub fn WebGPURenderer::invalidate_mesh(
  self : WebGPURenderer,
  node_id : UInt64,
) -> Unit {
  ignore(self.mesh_cache.remove(node_id))
}

///| 取或建 mesh 的 GPU 资源:lit 材质且几何带法线 → 追加法线缓冲与
///| 光照尺寸 uniform;否则走 Basic 布局(缺法线的 lit 材质降级 Basic)
fn WebGPURenderer::ensure_gpu_mesh(
  self : WebGPURenderer,
  node : @core.Object3D,
) -> GpuMesh raise Error {
  match self.mesh_cache.get(node.id) {
    Some(g) => return g
    None => ()
  }
  let m = match node.mesh {
    Some(m) => m
    None => raise Failure("node has no mesh")
  }
  let positions = f32_array_bytes(m.geometry.positions)
  let indices = u32_array_bytes(m.geometry.indices)
  let vbuf = self.device.create_buffer_init(
    usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_VERTEX),
    positions,
  )
  let ibuf = self.device.create_buffer_init(
    usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_INDEX),
    indices,
  )
  let lit = m.material.lit() && m.geometry.normals.length() > 0
  let nbuf = if lit {
    Some(
      self.device.create_buffer_init(
        usage=@wgpu_mbt.BufferUsage::from_u64(
          @wgpu_mbt.BUFFER_USAGE_VERTEX,
        ),
        f32_array_bytes(m.geometry.normals),
      ),
    )
  } else {
    None
  }
  // uv/顶点色缓冲:几何缺属性补默认(uv=(0,0) 无效采样位、色=白乘法恒等),
  // lit 管线顶点布局恒四槽,免按属性分派管线变体
  let vcount = m.geometry.vertex_count()
  let (uvbuf, cbuf) = if lit {
    let uv_bytes = if m.geometry.uvs.length() == vcount * 2 {
      f32_array_bytes(m.geometry.uvs)
    } else {
      zero_bytes(vcount * 2 * 4)
    }
    let c_bytes = if m.geometry.colors.length() == vcount * 3 {
      f32_array_bytes(m.geometry.colors)
    } else {
      white_f32_bytes(vcount * 3)
    }
    (
      Some(
        self.device.create_buffer_init(
          usage=@wgpu_mbt.BufferUsage::from_u64(
            @wgpu_mbt.BUFFER_USAGE_VERTEX,
          ),
          uv_bytes,
        ),
      ),
      Some(
        self.device.create_buffer_init(
          usage=@wgpu_mbt.BufferUsage::from_u64(
            @wgpu_mbt.BUFFER_USAGE_VERTEX,
          ),
          c_bytes,
        ),
      ),
    )
  } else {
    (None, None)
  }
  let ubuf = self.device.create_buffer(
    size=if lit { lit_uniform_size } else { uniform_size },
    usage=@wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_UNIFORM |
      @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    ),
  )
  let bgb = @wgpu_mbt.BindGroupBuilder::new(max_entries=1UL)
  let _ok = bgb.add_buffer(0U, ubuf)
  let bind_group = bgb.finish(self.device, self.bgl)
  let g : GpuMesh = {
    vbuf,
    nbuf,
    uvbuf,
    cbuf,
    ibuf,
    ubuf,
    bind_group,
    index_count: Int::reinterpret_as_uint(m.geometry.index_count()),
  }
  self.mesh_cache.set(node.id, g)
  g
}

///| 渲染一帧:clear 背景与深度,按材质分派管线——Lambert/Phong 走光照
///| 管线(世界空间法线 + SceneLights),Basic 或缺法线的 lit 走纯色管线
pub fn WebGPURenderer::render(
  self : WebGPURenderer,
  scene : @core.Scene,
  camera : @core.PerspectiveCamera,
) -> Unit raise Error {
  let depth_view = match self.depth_view {
    Some(v) => v
    None => raise Failure("no depth view")
  }
  scene.update_matrix_world()
  let vp = camera.projection_matrix.multiply(camera.view_matrix())
  // 收集可见 mesh 节点
  let nodes : Array[@core.Object3D] = []
  scene.root.traverse(fn(o) {
    if o.visible && o.mesh is Some(_) {
      nodes.push(o)
    }
    true
  })
  let st = self.surface.get_current_texture()
  if !st.is_success() {
    st.release()
    if !self.warned_acquire {
      // 尺寸失配(窗口 resize 后未重配)等会让 acquire 持续 Outdated,
      // 首次失败打出避免整段静默黑屏难排查
      println("renderer: acquire 失败 status=\{st.status()}(检查 surface 尺寸与窗口是否一致)")
      self.warned_acquire = true
    }
    return
  }
  let tex = st.take_texture()
  let color_view = tex.create_view()
  let encoder = self.device.create_command_encoder()
  let bg = match scene.background {
    Some(c) => c
    None => @math3d.Color::new(0.1, 0.12, 0.16)
  }
  let pass = encoder.begin_render_pass_color_depth_u32(
    color_view,
    depth_view,
    color_load_op_u32=@wgpu_mbt.LOAD_OP_CLEAR,
    color_store_op_u32=@wgpu_mbt.STORE_OP_STORE,
    color_clear_r_f32=Float::from_double(bg.r),
    color_clear_g_f32=Float::from_double(bg.g),
    color_clear_b_f32=Float::from_double(bg.b),
    color_clear_a_f32=1.0,
    depth_load_op_u32=@wgpu_mbt.LOAD_OP_CLEAR,
    depth_store_op_u32=@wgpu_mbt.STORE_OP_STORE,
    depth_clear_value_f32=1.0,
  )
  for node in nodes {
    let g = self.ensure_gpu_mesh(node)
    let m = node.mesh.unwrap()
    match g.nbuf {
      Some(nbuf) => {
        // lit 路径:model 与 normal 矩阵(model 逆转置)入 uniform
        let model = node.matrix_world
        let normal_mat = model.invert().transpose()
        let ub = lit_uniform_bytes(
          vp.multiply(model),
          model,
          normal_mat,
          camera.view_matrix(),
          camera.obj.world_position(),
          m.material,
          scene.lights,
          scene.fog,
        )
        self.queue.write_buffer(g.ubuf, 0UL, ub)
        pass.set_pipeline(self.pipeline_lit)
        pass.set_bind_group0(g.bind_group)
        // group(1):材质贴图(无 map 绑 1×1 白,统一采样路径)
        let gt = match m.material.map {
          Some(t) =>
            self.ensure_gpu_texture(t) catch { _ => self.white_texture() }
          None => self.white_texture()
        }
        pass.set_bind_group(1U, gt.bind_group, [])
        pass.set_vertex_buffer(0U, g.vbuf, 0UL, g.vbuf.get_size())
        pass.set_vertex_buffer(1U, nbuf, 0UL, nbuf.get_size())
        pass.set_vertex_buffer(
          2U,
          g.uvbuf.unwrap(),
          0UL,
          g.uvbuf.unwrap().get_size(),
        )
        pass.set_vertex_buffer(
          3U,
          g.cbuf.unwrap(),
          0UL,
          g.cbuf.unwrap().get_size(),
        )
        pass.set_index_buffer_u32(g.ibuf, 0UL, g.ibuf.get_size())
        pass.draw_indexed(g.index_count, 1U, 0U, 0, 0U)
      }
      None => {
        // Basic 路径:uniform = mvp + color(rgba)。布局与 lit 同构
        // (双 BGL),group(1) 必须同样设置 —— shader 虽不采样,绑白占位
        let ub = uniform_bytes(vp.multiply(node.matrix_world), m.material.color)
        self.queue.write_buffer(g.ubuf, 0UL, ub)
        let gw = self.white_texture()
        pass.set_pipeline(self.pipeline_basic)
        pass.set_bind_group0(g.bind_group)
        pass.set_bind_group(1U, gw.bind_group, [])
        pass.set_vertex_buffer(0U, g.vbuf, 0UL, g.vbuf.get_size())
        pass.set_index_buffer_u32(g.ibuf, 0UL, g.ibuf.get_size())
        pass.draw_indexed(g.index_count, 1U, 0U, 0, 0U)
      }
    }
  }
  pass.end()
  self.queue.submit_one(encoder.finish())
  let _ = self.surface.present()
}
