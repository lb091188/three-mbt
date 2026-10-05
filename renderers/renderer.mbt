// WebGPURenderer:建在 wgpu_mbt 之上的帧渲染器。
// surface 由宿主窗口的原生句柄创建(X11 与 Win32 路径均已真机趟通)。

///|
/// 单个 mesh 的 GPU 资源(顶点/索引/uniform/绑定组;法线缓冲仅 lit 材质有)
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
  /// 顶点数(非索引化线几何 draw 计数;索引化走 index_count)
  vertex_count : UInt
}

///|
/// WebGPU 渲染器
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
  /// 阴影深度管线(A5;只写深度,正面剔除)
  pipeline_shadow : @wgpu_mbt.RenderPipeline
  /// 线管线(A7):Line 折线条带 / LineSegments 独立线段
  pipeline_line_strip : @wgpu_mbt.RenderPipeline
  pipeline_line_list : @wgpu_mbt.RenderPipeline
  /// 公告板透明管线(Sprite kind=3 / Particle kind=4;A8)
  pipeline_sprite : @wgpu_mbt.RenderPipeline
  bgl : @wgpu_mbt.BindGroupLayout
  /// group(2) 布局:深度纹理+比较采样器(A5 阴影)
  shadow_bgl : @wgpu_mbt.BindGroupLayout
  /// 深度比较采样器(LESS;2x2 PCF 由 shader 偏移采样组成)
  shadow_sampler : @wgpu_mbt.Sampler
  /// 当前 shadow map(方向光 cast_shadow 且 map_size 变更时重建)
  mut shadow_map : GpuShadowMap?
  /// 1×1 占位深度绑定组(阴影关闭时 group(2) 合法占位,惰性建)
  mut empty_shadow : @wgpu_mbt.BindGroup?
  mut width : UInt
  mut height : UInt
  mut depth_view : @wgpu_mbt.TextureView?
  /// 节点 id → GPU 资源缓存(geometry/材质变更后调 invalidate_mesh)
  mut mesh_cache : @hashmap.HashMap[UInt64, GpuMesh]
  /// acquire 首败只警告一次
  mut warned_acquire : Bool
}

///|
/// 从 X11 原生句柄创建渲染器(display/xid 由宿主窗口层换算)
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
    @wgpu_mbt.TextureUsage::from_u64(@wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT),
  )
  // uniform BGL:便捷版固定 Fragment 可见性,顶点阶段用 mvp 必须
  // VERTEX|FRAGMENT,走通用 BindGroupLayoutBuilder(Basic/lit 两管线共用)
  let bglb = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=1UL)
  let _bgl_ok = bglb.add_buffer(
    0U,
    @wgpu_mbt.ShaderStage::from_u64(
      @wgpu_mbt.SHADER_STAGE_VERTEX | @wgpu_mbt.SHADER_STAGE_FRAGMENT,
    ),
    @wgpu_mbt.BUFFER_BINDING_TYPE_UNIFORM,
  )
  let bgl = bglb.finish(device)
  let tex_bgl = create_texture_bgl(device)
  let shadow_bgl = create_shadow_bgl(device)
  let shadow_sampler = create_shadow_compare_sampler(device)
  let pipeline = create_basic_pipeline(device, format, bgl, tex_bgl)
  let lit_pipeline = create_lit_pipeline(
    device, format, bgl, tex_bgl, shadow_bgl,
  )
  let shadow_pipeline = create_shadow_pipeline(device, bgl)
  let line_strip = create_line_pipeline(
    device,
    format,
    bgl,
    tex_bgl,
    @wgpu_mbt.PRIMITIVE_TOPOLOGY_LINE_STRIP,
  )
  let line_list = create_line_pipeline(
    device,
    format,
    bgl,
    tex_bgl,
    @wgpu_mbt.PRIMITIVE_TOPOLOGY_LINE_LIST,
  )
  let sprite_pipeline = create_sprite_pipeline(device, format, bgl, tex_bgl)
  let r : WebGPURenderer = {
    instance,
    adapter,
    device,
    queue,
    surface,
    format,
    pipeline_basic: pipeline,
    pipeline_lit: lit_pipeline,
    pipeline_shadow: shadow_pipeline,
    pipeline_line_strip: line_strip,
    pipeline_line_list: line_list,
    pipeline_sprite: sprite_pipeline,
    bgl,
    tex_bgl,
    shadow_bgl,
    shadow_sampler,
    shadow_map: None,
    empty_shadow: None,
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

///|
/// 重建深度附着(resize 后调)
fn WebGPURenderer::rebuild_depth(self : WebGPURenderer) -> Unit {
  let tex = self.device.create_texture_depth24plus_2d(self.width, self.height)
  self.depth_view = Some(tex.create_view())
}

///|
/// 尺寸变化:重配 surface 与深度附着(格式沿用)
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
    @wgpu_mbt.TextureUsage::from_u64(@wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT),
  )
  self.rebuild_depth()
}

///|
/// geometry/材质变更后清缓存(节点 id;材质 kind 变更同样需失效重建)
pub fn WebGPURenderer::invalidate_mesh(
  self : WebGPURenderer,
  node_id : UInt64,
) -> Unit {
  ignore(self.mesh_cache.remove(node_id))
}

///| 取或建 mesh 的 GPU 资源:lit 材质且几何带法线 → 追加法线缓冲与

///|
/// 光照尺寸 uniform;否则走 Basic 布局(缺法线的 lit 材质降级 Basic)
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
  // 索引缓冲:非索引化线几何(indices 空)建 4B 占位,draw 走非索引化路径
  // 永不消费它;0 尺寸缓冲 wgpu 拒建,故必须垫底
  let ibuf = if indices.length() > 0 {
    self.device.create_buffer_init(
      usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_INDEX),
      indices,
    )
  } else {
    self.device.create_buffer_init(
      usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_INDEX),
      u32_array_bytes([0U]),
    )
  }
  let is_line = m.topology != 0
  let lit = !is_line && m.material.lit() && m.geometry.normals.length() > 0
  let billboard = m.material.is_billboard()
  let nbuf = if lit {
    Some(
      self.device.create_buffer_init(
        usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_VERTEX),
        f32_array_bytes(m.geometry.normals),
      ),
    )
  } else {
    None
  }
  // uv 缓冲:lit 与公告板两族管线都要采样;几何缺属性补 (0,0) 默认。
  // 顶点色缓冲:lit 管线槽3(缺色补白乘法恒等)、线管线恒两槽(位置+顶点色,
  // 缺色补白);公告板管线顶点布局只有位置+uv 两槽,免按属性分派管线变体
  let vcount = m.geometry.vertex_count()
  let uv_bytes = if m.geometry.uvs.length() == vcount * 2 {
    f32_array_bytes(m.geometry.uvs)
  } else {
    zero_bytes(vcount * 2 * 4)
  }
  let uvbuf = if lit || billboard {
    Some(
      self.device.create_buffer_init(
        usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_VERTEX),
        uv_bytes,
      ),
    )
  } else {
    None
  }
  let cbuf = if lit {
    let c_bytes = if m.geometry.colors.length() == vcount * 3 {
      f32_array_bytes(m.geometry.colors)
    } else {
      white_f32_bytes(vcount * 3)
    }
    Some(
      self.device.create_buffer_init(
        usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_VERTEX),
        c_bytes,
      ),
    )
  } else if is_line {
    // 线管线槽1 恒顶点色:几何缺 colors 补白(乘主色恒等,顶点色可选)
    Some(
      self.device.create_buffer_init(
        usage=@wgpu_mbt.BufferUsage::from_u64(@wgpu_mbt.BUFFER_USAGE_VERTEX),
        line_color_bytes(m.geometry),
      ),
    )
  } else {
    None
  }
  let ubuf = self.device.create_buffer(
    size=if lit {
      lit_uniform_size
    } else if billboard {
      sprite_uniform_size
    } else {
      uniform_size
    },
    usage=@wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_UNIFORM | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
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
    vertex_count: Int::reinterpret_as_uint(vcount),
  }
  self.mesh_cache.set(node.id, g)
  g
}

///| 渲染一帧:clear 背景与深度,按材质分派管线——Lambert/Phong 走光照

///| 管线(世界空间法线 + SceneLights),Basic 或缺法线的 lit 走纯色管线;

///| Sprite/Particle(kind 3/4)走公告板透明管线,不透明几何之后按

///|
/// 相机距离由远及近排序绘制(alpha 混合的正确次序;A8)
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
  // 收集可见 mesh 节点,按材质族分流:公告板材质延迟到不透明之后画
  let nodes : Array[@core.Object3D] = []
  let billboards : Array[@core.Object3D] = []
  scene.root.traverse(fn(o) {
    if o.visible && o.mesh is Some(_) {
      if o.mesh.unwrap().material.is_billboard() {
        billboards.push(o)
      } else {
        nodes.push(o)
      }
    }
    true
  })
  let st = self.surface.get_current_texture()
  if !st.is_success() {
    st.release()
    if !self.warned_acquire {
      // 尺寸失配(窗口 resize 后未重配)等会让 acquire 持续 Outdated,
      // 首次失败打出避免整段静默黑屏难排查
      println(
        "renderer: acquire 失败 status=\{st.status()}(检查 surface 尺寸与窗口是否一致)",
      )
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
  // ---- A5 阴影深度 pass:方向光 cast_shadow 时先渲 shadow map。
  // 独立编码+先提交:caster 的 ubuf 在主 pass 会被改写为 lit 内容,
  // 同一缓冲同偏移两次 write_buffer 必须用队列序隔开(提交边界保证
  // 阴影 pass 读到的是 mvp、主 pass 读到的是 lit 段)
  let mut shadow_matrix = @math3d.Matrix4::identity()
  let mut shadow_bg : @wgpu_mbt.BindGroup? = None
  match scene.lights.directional {
    Some(d) if d.cast_shadow => {
      let gsm = self.ensure_shadow_map(d.shadow.map_size)
      let casters = collect_shadow_casters(scene)
      if casters.length() > 0 {
        let lvp = shadow_light_matrix(d)
        shadow_matrix = lvp
        let senc = self.device.create_command_encoder()
        let sp = senc.begin_render_pass_depth_u32(
          gsm.view,
          depth_load_op_u32=@wgpu_mbt.LOAD_OP_CLEAR,
          depth_store_op_u32=@wgpu_mbt.STORE_OP_STORE,
          depth_clear_value_f32=1.0,
        )
        sp.set_pipeline(self.pipeline_shadow)
        for node in casters {
          let g = self.ensure_gpu_mesh(node)
          self.queue.write_buffer(
            g.ubuf,
            0UL,
            shadow_uniform_bytes(lvp.multiply(node.matrix_world)),
          )
          sp.set_bind_group0(g.bind_group)
          sp.set_vertex_buffer(0U, g.vbuf, 0UL, g.vbuf.get_size())
          sp.set_index_buffer_u32(g.ibuf, 0UL, g.ibuf.get_size())
          sp.draw_indexed(g.index_count, 1U, 0U, 0, 0U)
        }
        sp.end()
        self.queue.submit_one(senc.finish())
      }
      shadow_bg = Some(gsm.bind_group)
    }
    _ => ()
  }
  for node in nodes {
    let g = self.ensure_gpu_mesh(node)
    let m = node.mesh.unwrap()
    // 线路径(Line/LineSegments):basic 族 uniform + 线拓扑管线
    if m.topology != 0 {
      self.draw_line(
        pass,
        g,
        vp.multiply(node.matrix_world),
        m.material.color,
        m.topology,
      )
      continue
    }
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
          shadow_matrix,
          m.receive_shadow,
        )
        self.queue.write_buffer(g.ubuf, 0UL, ub)
        pass.set_pipeline(self.pipeline_lit)
        pass.set_bind_group0(g.bind_group)
        // group(1):材质贴图(无 map 绑 1×1 白,统一采样路径)
        let gt = match m.material.map {
          Some(t) =>
            self.ensure_gpu_texture(t) catch {
              _ => self.white_texture()
            }
          None => self.white_texture()
        }
        pass.set_bind_group(1U, gt.bind_group, [])
        // group(2):shadow map(阴影关闭绑 1×1 占位,shader w=0 短路)
        let sbg = match shadow_bg {
          Some(bg) => bg
          None => self.empty_shadow_bind_group()
        }
        pass.set_bind_group(2U, sbg, [])
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
  // 公告板透明序列(A8):按到相机距离平方由远及近排序(alpha 混合的
  // 正确绘制次序),不透明几何全部出队后开始
  if billboards.length() > 0 {
    let ce = camera.obj.matrix_world.e
    let cam_pos = @math3d.Vector3::new(ce[12], ce[13], ce[14])
    let keyed : Array[(Double, @core.Object3D)] = []
    for o in billboards {
      let e = o.matrix_world.e
      let dx = e[12] - cam_pos.x
      let dy = e[13] - cam_pos.y
      let dz = e[14] - cam_pos.z
      keyed.push((dx * dx + dy * dy + dz * dz, o))
    }
    keyed.sort_by(fn(a, b) {
      if a.0 > b.0 {
        -1
      } else if a.0 < b.0 {
        1
      } else {
        0
      }
    })
    for entry in keyed {
      let node = entry.1
      let g = self.ensure_gpu_mesh(node)
      let m = node.mesh.unwrap()
      // 粒子路径:几何 positions 每帧 CPU 重写(含死粒子退化折叠),
      // 顶点缓冲整段重传;精灵路径几何静态无需重传
      if m.material.is_particle() {
        self.queue.write_buffer(
          g.vbuf,
          0UL,
          f32_array_bytes(m.geometry.positions),
        )
      }
      let ub = if m.material.is_sprite() {
        // 精灵:节点世界位置/尺寸(世界矩阵列长)+ 相机右/上轴,
        // 锚点偏移折进 center(axis_z 恒零,几何 pos.z=0 不参与)
        let e = node.matrix_world.e
        let world_pos = @math3d.Vector3::new(e[12], e[13], e[14])
        let size_x = @math3d.Vector3::new(e[0], e[1], e[2]).length()
        let size_y = @math3d.Vector3::new(e[4], e[5], e[6]).length()
        let (right, up) = @core.billboard_axes(camera.obj.matrix_world)
        let center = world_pos.add(
          @core.sprite_anchor_shift(
            m.material.center,
            size_x,
            size_y,
            right,
            up,
          ),
        )
        sprite_uniform_bytes(
          vp,
          center,
          right.multiply_scalar(size_x),
          up.multiply_scalar(size_y),
          @math3d.Vector3::zero(),
          m.material.rotation,
          m.material.color,
          m.material.opacity,
        )
      } else {
        // 粒子:positions 已是世界四角,center 零、轴取恒等基
        sprite_uniform_bytes(
          vp,
          @math3d.Vector3::zero(),
          @math3d.Vector3::unit_x(),
          @math3d.Vector3::unit_y(),
          @math3d.Vector3::unit_z(),
          0.0,
          m.material.color,
          m.material.opacity,
        )
      }
      self.queue.write_buffer(g.ubuf, 0UL, ub)
      // group(1):材质贴图(无 map 绑 1×1 白)
      let gt = match m.material.map {
        Some(t) =>
          self.ensure_gpu_texture(t) catch {
            _ => self.white_texture()
          }
        None => self.white_texture()
      }
      pass.set_pipeline(self.pipeline_sprite)
      pass.set_bind_group0(g.bind_group)
      pass.set_bind_group(1U, gt.bind_group, [])
      pass.set_vertex_buffer(0U, g.vbuf, 0UL, g.vbuf.get_size())
      let uvb = g.uvbuf.unwrap()
      pass.set_vertex_buffer(1U, uvb, 0UL, uvb.get_size())
      pass.set_index_buffer_u32(g.ibuf, 0UL, g.ibuf.get_size())
      pass.draw_indexed(g.index_count, 1U, 0U, 0, 0U)
    }
  }
  pass.end()
  self.queue.submit_one(encoder.finish())
  let _ = self.surface.present()
}

///| 线节点绘制:uniform 与 basic 同构(mvp + 主色),顶点色槽恒绑

///|(无顶点色的几何建 GPU 资源时已补白);索引化几何走 draw_indexed,

///|
/// 非索引化折线走 draw(顶点数)
fn WebGPURenderer::draw_line(
  self : WebGPURenderer,
  pass : @wgpu_mbt.RenderPass,
  g : GpuMesh,
  mvp : @math3d.Matrix4,
  color : @math3d.Color,
  topology : Int,
) -> Unit raise Error {
  let ub = uniform_bytes(mvp, color)
  self.queue.write_buffer(g.ubuf, 0UL, ub)
  let gw = self.white_texture()
  match topology {
    1 => pass.set_pipeline(self.pipeline_line_strip)
    _ => pass.set_pipeline(self.pipeline_line_list)
  }
  pass.set_bind_group0(g.bind_group)
  pass.set_bind_group(1U, gw.bind_group, [])
  pass.set_vertex_buffer(0U, g.vbuf, 0UL, g.vbuf.get_size())
  match g.cbuf {
    Some(c) => pass.set_vertex_buffer(1U, c, 0UL, c.get_size())
    None => ()
  }
  if g.index_count > 0U {
    pass.set_index_buffer_u32(g.ibuf, 0UL, g.ibuf.get_size())
    pass.draw_indexed(g.index_count, 1U, 0U, 0, 0U)
  } else {
    pass.draw(g.vertex_count, 1U, 0U, 0U)
  }
}

///| 运行时更新顶点缓冲:把几何当前 positions 全量重传到已建的 vbuf。

///| 顶点数未变(字节数与 vbuf 等大)→ 原地写缓冲返回 true;顶点数变了 →

///| 失效缓存按新数组重建返回 false;GPU 资源未建 → 返回 false(下帧

///|
/// render 会按当前几何新建,无需调用方补救)。动态折线每帧调用。
pub fn WebGPURenderer::update_vertices(
  self : WebGPURenderer,
  node : @core.Object3D,
) -> Bool {
  let m = match node.mesh {
    Some(m) => m
    None => return false
  }
  match self.mesh_cache.get(node.id) {
    Some(g) => {
      let size = Int::to_uint64(m.geometry.positions.length() * 4)
      if size == g.vbuf.get_size() {
        self.queue.write_buffer(
          g.vbuf,
          0UL,
          f32_array_bytes(m.geometry.positions),
        )
        true
      } else {
        self.invalidate_mesh(node.id)
        false
      }
    }
    None => false
  }
}

///| 运行时更新单个顶点(动态折线每帧只动一个端点的最小写入):

///| 同步几何数组 + 12 字节局部写 vbuf 偏移 index*12。返回 true=已写入

///| GPU;false=GPU 资源未建或顶点数与已建缓冲失配(几何数组已更新,

///|
/// 下帧 render/invalidate 后按新数据生效);越界忽略返回 false。
pub fn WebGPURenderer::update_vertex(
  self : WebGPURenderer,
  node : @core.Object3D,
  index : Int,
  x : Double,
  y : Double,
  z : Double,
) -> Bool {
  let m = match node.mesh {
    Some(m) => m
    None => return false
  }
  let n = m.geometry.vertex_count()
  if index < 0 || index >= n {
    return false
  }
  m.geometry.set_vertex(index, x, y, z)
  match self.mesh_cache.get(node.id) {
    Some(g) =>
      if Int::to_uint64(n * 12) == g.vbuf.get_size() {
        self.queue.write_buffer(
          g.vbuf,
          (index * 12).to_uint64(),
          f32x3_bytes(x, y, z),
        )
        true
      } else {
        false
      }
    None => false
  }
}
