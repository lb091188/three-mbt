// three.js MathUtils 迁移:常数与标量工具函数,静态方法挂 MathUtils 命名空间。
// 未迁:generateUUID/randInt/randFloat/randFloatSpread(依赖 Math.random,
// moonbitlang/core/random 未在本包 import,且随机数应上层注入)、
// normalize/denormalize(依赖 JS TypedArray 概念,属渲染层职责)。

///| 度转弧度系数(three.js DEG2RAD,Math.PI/180 的精确双精度值)
pub const DEG2RAD : Double = 0.017453292519943295

///| 弧度转度系数(three.js RAD2DEG,180/Math.PI 的精确双精度值)
pub const RAD2DEG : Double = 57.29577951308232

///| 标量数学工具命名空间(只承载静态方法,不实例化)
pub(all) struct MathUtils {}

// JS `%`(C fmod)语义:商向零截断,余数符号随被除数。
// 以 a - trunc(a/b)*b 实现;a/b 非精确表示时与位级 fmod 可能有尾差,
// 常规角度量级输入下结果精确。
fn mu_js_mod(a : Double, b : Double) -> Double {
  a - @math.trunc(a / b) * b
}

///| 将值夹在 [min, max](three.js MathUtils.clamp 同式)
pub fn MathUtils::clamp(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  max_double(min, min_double(max, value))
}

///| 欧几里得取余:`((n % m) + m) % m`,结果与 m 同号非负
pub fn MathUtils::euclidean_modulo(n : Double, m : Double) -> Double {
  mu_js_mod(mu_js_mod(n, m) + m, m)
}

///| 线性区间映射 <a1,a2> → <b1,b2>
pub fn MathUtils::map_linear(
  x : Double,
  a1 : Double,
  a2 : Double,
  b1 : Double,
  b2 : Double,
) -> Double {
  b1 + (x - a1) * (b2 - b1) / (a2 - a1)
}

///| 逆插值:value 在 [x,y] 中的比例;x==y 时返回 0
pub fn MathUtils::inverse_lerp(
  x : Double,
  y : Double,
  value : Double,
) -> Double {
  if x != y {
    (value - x) / (y - x)
  } else {
    0.0
  }
}

///| 线性插值:`(1-t)*x + t*y`(three.js MathUtils.lerp 原式,与 Vector 系
///| 的 x+(y-x)*t 写法不同,浮点结果可能有一位尾差)
pub fn MathUtils::lerp(x : Double, y : Double, t : Double) -> Double {
  (1.0 - t) * x + t * y
}

///| 帧率无关阻尼插值(spring 风格,按 delta time)
pub fn MathUtils::damp(
  x : Double,
  y : Double,
  lambda : Double,
  dt : Double,
) -> Double {
  MathUtils::lerp(x, y, 1.0 - @math.exp(-lambda * dt))
}

///| 在 0 与 length 之间往返
pub fn MathUtils::pingpong(x : Double, length : Double) -> Double {
  length -
  (MathUtils::euclidean_modulo(x, length * 2.0) - length).abs()
}

///| 平滑阶跃 [0,1](端点处一阶导为 0)
pub fn MathUtils::smoothstep(
  x : Double,
  min : Double,
  max : Double,
) -> Double {
  if x <= min {
    return 0.0
  }
  if x >= max {
    return 1.0
  }
  let t = (x - min) / (max - min)
  t * t * (3.0 - 2.0 * t)
}

///| 更平滑阶跃 [0,1](端点处一阶/二阶导均为 0)
pub fn MathUtils::smootherstep(
  x : Double,
  min : Double,
  max : Double,
) -> Double {
  if x <= min {
    return 0.0
  }
  if x >= max {
    return 1.0
  }
  let t = (x - min) / (max - min)
  t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
}

///| 度 → 弧度
pub fn MathUtils::deg_to_rad(degrees : Double) -> Double {
  degrees * DEG2RAD
}

///| 弧度 → 度
pub fn MathUtils::rad_to_deg(radians : Double) -> Double {
  radians * RAD2DEG
}

///| 是否 2 的幂(对正整数输入与 three.js 的 log2 取整公式等价,
///| 位判式无浮点边界问题)
pub fn MathUtils::is_power_of_two(value : Int) -> Bool {
  value > 0 &&
  (value.reinterpret_as_uint() & (value - 1).reinterpret_as_uint()) == 0
}

///| 最小的 ≥ value 的 2 的幂(value ≥ 1)
pub fn MathUtils::ceil_power_of_two(value : Int) -> Int {
  let mut p = 1
  while p < value {
    p = p * 2
  }
  p
}

///| 最大的 ≤ value 的 2 的幂(value ≥ 1)
pub fn MathUtils::floor_power_of_two(value : Int) -> Int {
  let mut p = 1
  while p * 2 <= value {
    p = p * 2
  }
  p
}

///| Proper Euler 轴序(three.js setQuaternionFromProperEuler 支持的六种)
pub(all) enum ProperEulerOrder {
  XYX
  XZX
  YXY
  YZY
  ZXZ
  ZYZ
}

///| 解析 Proper Euler 轴序字符串(three.js 以 'XYX' 等字符串表示轴序;
///| 大小写敏感,未知串返回 None)
pub fn MathUtils::proper_euler_order_from_string(
  s : String,
) -> ProperEulerOrder? {
  match s {
    "XYX" => Some(XYX)
    "XZX" => Some(XZX)
    "YXY" => Some(YXY)
    "YZY" => Some(YZY)
    "ZXZ" => Some(ZXZ)
    "ZYZ" => Some(ZYZ)
    _ => None
  }
}

///| 由 Intrinsic Proper Euler 角构造四元数;先绕首轴转 a、再 b、再 c
///| (three.js MathUtils.setQuaternionFromProperEuler 同式)
pub fn MathUtils::set_quaternion_from_proper_euler(
  a : Double,
  b : Double,
  c : Double,
  order : ProperEulerOrder,
) -> Quaternion {
  let c2 = @math.cos(b / 2.0)
  let s2 = @math.sin(b / 2.0)
  let c13 = @math.cos((a + c) / 2.0)
  let s13 = @math.sin((a + c) / 2.0)
  let c1_3 = @math.cos((a - c) / 2.0)
  let s1_3 = @math.sin((a - c) / 2.0)
  let c3_1 = @math.cos((c - a) / 2.0)
  let s3_1 = @math.sin((c - a) / 2.0)
  match order {
    XYX => { x: c2 * s13, y: s2 * c1_3, z: s2 * s1_3, w: c2 * c13 }
    YZY => { x: s2 * s1_3, y: c2 * s13, z: s2 * c1_3, w: c2 * c13 }
    ZXZ => { x: s2 * c1_3, y: s2 * s1_3, z: c2 * s13, w: c2 * c13 }
    XZX => { x: c2 * s13, y: s2 * s3_1, z: s2 * c3_1, w: c2 * c13 }
    YXY => { x: s2 * c3_1, y: c2 * s13, z: s2 * s3_1, w: c2 * c13 }
    ZYZ => { x: s2 * s3_1, y: s2 * c3_1, z: c2 * s13, w: c2 * c13 }
  }
}

// ---- Mulberry32 确定性伪随机(three.js seededRandom)----
// JS 的 ToInt32/>>>/imul 语义以 UInt64 承载的"无符号 32 位规范形"
// 逐位模拟(加减乘保证不溢出 64 位,mod 2^32 用掩码),与 JS 位级一致。
// three.js 模块级 _seed,初值 1234567(顶层 let 不可变,以单元素数组承载可变态)
let mu_seed : Array[UInt64] = [1234567]

// 32 位回绕加
fn mu_add32(a : UInt64, b : UInt64) -> UInt64 {
  (a + b) & 4294967295
}

// 32 位乘法 mod 2^32(16 位分解;a1*b1 项落在被丢弃的 ≥2^32 高位,
// a0*b0 的高 16 位作为进位并入中间项)
fn mu_imul32(a : UInt64, b : UInt64) -> UInt64 {
  let a0 = a & 65535
  let a1 = a >> 16
  let b0 = b & 65535
  let b1 = b >> 16
  let low = a0 * b0
  let mid = (a0 * b1 + a1 * b0 + (low >> 16)) & 65535
  ((low & 65535) + mid * 65536) & 4294967295
}

// 从已步进的种子 t0 生成 [0,1) 浮点(three.js seededRandom 主体同式)
fn mu_generate(t0 : UInt64) -> Double {
  let t1 = mu_imul32(t0 ^ (t0 >> 15), t0 | 1)
  let t2 = t1 ^ mu_add32(t1, mu_imul32(t1 ^ (t1 >> 7), t1 | 61))
  let t3 = t2 ^ (t2 >> 14)
  t3.to_double() / 4294967296.0
}

// 种子步进:+0x6D2B79F5(= 1831565813)后返回新种子
fn mu_step() -> UInt64 {
  mu_seed[0] = mu_add32(mu_seed[0], 0x6D2B79F5)
  mu_seed[0]
}

///| 确定性伪随机 [0,1](Mulberry32,续用全局种子;跨调用保持序列)
pub fn MathUtils::seeded_random() -> Double {
  mu_generate(mu_step())
}

///| 重置全局种子后生成一个确定性伪随机值(等价 three.js seededRandom(s))
pub fn MathUtils::seeded_random_with(s : Int) -> Double {
  // 负种子按补码位模式解释,等价 JS ToUint32
  mu_seed[0] = s.reinterpret_as_uint().to_uint64()
  MathUtils::seeded_random()
}
