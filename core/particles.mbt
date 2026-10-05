// three.js Points 粒子的游戏向最简替代(A8):CPU 步进位置/寿命,
// 每帧把活粒子写成公告板四角、死粒子折叠为退化三角形(四顶点同点,
// 零面积不光栅化)。无实例化:一个粒子 = 动态 BufferGeometry 里 4 顶点
// + 6 索引,几何顶点缓冲按最大容量预分配,渲染层每帧 write_buffer 重传。
// 渲染派发:obj.mesh 材质 kind=4(particle),节点变换须保持恒等
// (粒子坐标即世界坐标,直接进视图投影)。

///|
/// 单个粒子(全部字段可变,由粒子系统步进驱动)
pub(all) struct Particle {
  /// 位置(世界坐标)
  mut px : Double
  mut py : Double
  mut pz : Double
  /// 速度(世界坐标/秒)
  mut vx : Double
  mut vy : Double
  mut vz : Double
  /// 已存活时间(秒)
  mut age : Double
  /// 寿命(秒;age >= max_life 判死)
  mut max_life : Double
  /// 四边形边长(米;公告板 X/Y 同尺寸)
  mut size : Double
  mut alive : Bool
}

///|
/// 死粒子(初值占位;位置 0,四角折叠在原点)
fn Particle::dead() -> Particle {
  {
    px: 0.0,
    py: 0.0,
    pz: 0.0,
    vx: 0.0,
    vy: 0.0,
    vz: 0.0,
    age: 0.0,
    max_life: 0.0,
    size: 0.0,
    alive: false,
  }
}

///|
/// 粒子系统(预分配池 + 动态几何;obj 挂进场景,自身保持恒等变换)
pub(all) struct ParticleSystem {
  /// 挂进场景的节点(mesh = 动态几何 + kind=4 材质)
  obj : Object3D
  /// 动态几何(4*max 顶点;positions 每帧由 rebuild_geometry 重写)
  geometry : BufferGeometry
  /// 粒子池(定长;死位可复用)
  particles : Array[Particle]
  /// 重力加速度(加在 vy 上,负值下坠;默认 -9.8)
  mut gravity : Double
  /// 线性阻尼系数(每秒速度保留比例,1=无阻尼,0.9^t 量级;默认 1)
  mut damping : Double
  /// spawn 扫描游标(环形找死位,避免每次从头扫)
  mut spawn_cursor : Int
}

///|
/// 构造(max = 粒子池容量;material 一般为 Material::particle 带贴图)
pub fn ParticleSystem::new(max : Int, material : Material) -> ParticleSystem {
  let positions : Array[Double] = Array::make(max * 12, 0.0)
  // 每粒子 4 顶点全图 uv(静态,建池时写死)
  let uvs : Array[Double] = Array::make(max * 8, 0.0)
  let quad_uvs = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
  for i in 0..<max {
    for j in 0..<8 {
      uvs[i * 8 + j] = quad_uvs[j]
    }
  }
  let indices : Array[UInt] = Array::make(max * 6, 0U)
  for i in 0..<max {
    let b : UInt = (i * 4).reinterpret_as_uint()
    indices[i * 6] = b
    indices[i * 6 + 1] = b + 1
    indices[i * 6 + 2] = b + 2
    indices[i * 6 + 3] = b
    indices[i * 6 + 4] = b + 2
    indices[i * 6 + 5] = b + 3
  }
  let particles : Array[Particle] = []
  for _i in 0..<max {
    particles.push(Particle::dead())
  }
  let geometry : BufferGeometry = {
    positions,
    normals: [],
    uvs,
    colors: [],
    indices,
  }
  let obj = Object3D::new()
  // 粒子板不投/不收阴影(A5 阴影深度管线按三角面光栅化,透明板进去会
  // 烙出整片错误阴影;three.js Points.castShadow 默认 false 同语义)
  obj.mesh = Some({
    geometry,
    material,
    cast_shadow: false,
    receive_shadow: false,
    topology: 0,
  })
  { obj, geometry, particles, gravity: -9.8, damping: 1.0, spawn_cursor: 0, }
}

///|
/// 生成一个粒子(环形扫描死位;池满返回 false)
pub fn ParticleSystem::spawn(
  self : ParticleSystem,
  px : Double,
  py : Double,
  pz : Double,
  vx : Double,
  vy : Double,
  vz : Double,
  max_life : Double,
  size : Double,
) -> Bool {
  let n = self.particles.length()
  for k in 0..<n {
    let idx = (self.spawn_cursor + k) % n
    let p = self.particles[idx]
    if !p.alive {
      p.px = px
      p.py = py
      p.pz = pz
      p.vx = vx
      p.vy = vy
      p.vz = vz
      p.age = 0.0
      p.max_life = max_life
      p.size = size
      p.alive = true
      self.spawn_cursor = (idx + 1) % n
      return true
    }
  }
  false
}

///|
/// 活粒子数
pub fn ParticleSystem::alive_count(self : ParticleSystem) -> Int {
  let mut c = 0
  for p in self.particles {
    if p.alive {
      c = c + 1
    }
  }
  c
}

///| 物理步进:速度加重力与阻尼、位置积分、寿命累计与判死

///| (dt 为秒;阻尼按 1-(1-damping)*dt 线性近似,dt=帧步长下与

///|
/// pow(damping,dt) 同量级且确定可测)
pub fn ParticleSystem::integrate(self : ParticleSystem, dt : Double) -> Unit {
  let damp = 1.0 - (1.0 - self.damping) * dt
  for p in self.particles {
    if p.alive {
      p.vy = p.vy + self.gravity * dt
      p.vx = p.vx * damp
      p.vy = p.vy * damp
      p.vz = p.vz * damp
      p.px = p.px + p.vx * dt
      p.py = p.py + p.vy * dt
      p.pz = p.pz + p.vz * dt
      p.age = p.age + dt
      if p.age >= p.max_life {
        p.alive = false
      }
    }
  }
}

///| 重建动态几何:活粒子写公告板四角(右/上轴由调用方从相机取,

///| billboard_axes),死粒子四顶点折叠到自身最后位置(退化三角形,

///|
/// 零面积不产生片元)。顶点顺序与 sprite_quad 一致,uv/索引静态。
pub fn ParticleSystem::rebuild_geometry(
  self : ParticleSystem,
  right : @math3d.Vector3,
  up : @math3d.Vector3,
) -> Unit {
  let positions = self.geometry.positions
  for i, p in self.particles {
    let base = i * 4
    if p.alive {
      sprite_write_quad(
        positions,
        base,
        @math3d.Vector3::new(p.px, p.py, p.pz),
        p.size,
        p.size,
        right,
        up,
      )
    } else {
      // 退化折叠:四顶点同点(取死亡时的位置,无需归零)
      let k = base * 3
      for j in 0..<4 {
        positions[k + j * 3] = p.px
        positions[k + j * 3 + 1] = p.py
        positions[k + j * 3 + 2] = p.pz
      }
    }
  }
}

///|
/// 一步到位:物理积分 + 几何重建(示例/游戏主循环每帧调用一次)
pub fn ParticleSystem::step(
  self : ParticleSystem,
  dt : Double,
  right : @math3d.Vector3,
  up : @math3d.Vector3,
) -> Unit {
  self.integrate(dt)
  self.rebuild_geometry(right, up)
}
