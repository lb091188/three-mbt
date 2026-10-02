///|
test "MathUtils 常数与角度换算" {
  debug_inspect(@math3d.DEG2RAD, content="0.017453292519943295")
  debug_inspect(@math3d.RAD2DEG, content="57.29577951308232")
  debug_inspect(
    @math3d.MathUtils::deg_to_rad(180.0),
    content="3.141592653589793",
  )
  debug_inspect(@math3d.MathUtils::rad_to_deg(3.141592653589793), content=(
    #|180
  ))
}

///|
test "MathUtils clamp/euclideanModulo/lerp 族" {
  debug_inspect(@math3d.MathUtils::clamp(5.0, 0.0, 3.0), content="3")
  debug_inspect(@math3d.MathUtils::clamp(-1.0, 0.0, 3.0), content="0")
  debug_inspect(@math3d.MathUtils::clamp(2.0, 0.0, 3.0), content="2")
  debug_inspect(@math3d.MathUtils::euclidean_modulo(-1.0, 4.0), content="3")
  debug_inspect(@math3d.MathUtils::euclidean_modulo(5.0, 3.0), content="2")
  debug_inspect(@math3d.MathUtils::lerp(0.0, 10.0, 0.25), content="2.5")
  // lerp 原式 (1-t)x + ty:与 x+(y-x)t 写法的一致性
  debug_inspect(
    @math3d.MathUtils::lerp(1.0, 2.0, 0.5) ==
    (1.0 - 0.5) * 1.0 +
    0.5 * 2.0,
    content="true",
  )
  debug_inspect(
    @math3d.MathUtils::inverse_lerp(0.0, 10.0, 5.0),
    content="0.5",
  )
  debug_inspect(@math3d.MathUtils::inverse_lerp(3.0, 3.0, 7.0), content="0")
  debug_inspect(
    @math3d.MathUtils::map_linear(0.5, 0.0, 1.0, 10.0, 20.0),
    content="15",
  )
  // damp:lambda*dt 充分大时逼近目标(容差断言,避开 libm 逐位差异)
  let d = @math3d.MathUtils::damp(0.0, 1.0, 100.0, 0.1)
  debug_inspect(d > 0.999 && d < 1.0, content="true")
  debug_inspect(
    (@math3d.MathUtils::damp(2.0, 2.0, 5.0, 0.3) - 2.0).abs() < 0.000001,
    content="true",
  )
}

///|
test "MathUtils pingpong/smoothstep/smootherstep" {
  debug_inspect(@math3d.MathUtils::pingpong(0.5, 1.0), content="0.5")
  debug_inspect(@math3d.MathUtils::pingpong(1.5, 1.0), content="0.5")
  debug_inspect(@math3d.MathUtils::pingpong(-0.25, 1.0), content="0.25")
  debug_inspect(@math3d.MathUtils::smoothstep(0.0, 0.0, 1.0), content="0")
  debug_inspect(@math3d.MathUtils::smoothstep(1.0, 0.0, 1.0), content="1")
  debug_inspect(
    @math3d.MathUtils::smoothstep(0.5, 0.0, 1.0),
    content="0.5",
  )
  debug_inspect(
    @math3d.MathUtils::smoothstep(0.25, 0.0, 1.0),
    content="0.15625",
  )
  debug_inspect(@math3d.MathUtils::smootherstep(0.5, 0.0, 1.0), content=(
    #|0.5
  ))
  debug_inspect(
    @math3d.MathUtils::smootherstep(0.25, 0.0, 1.0),
    content="0.103515625",
  )
}

///|
test "MathUtils 2 的幂族" {
  debug_inspect(@math3d.MathUtils::is_power_of_two(1), content="true")
  debug_inspect(@math3d.MathUtils::is_power_of_two(2), content="true")
  debug_inspect(@math3d.MathUtils::is_power_of_two(1024), content="true")
  debug_inspect(@math3d.MathUtils::is_power_of_two(0), content="false")
  debug_inspect(@math3d.MathUtils::is_power_of_two(3), content="false")
  debug_inspect(@math3d.MathUtils::is_power_of_two(1023), content="false")
  debug_inspect(@math3d.MathUtils::ceil_power_of_two(1), content="1")
  debug_inspect(@math3d.MathUtils::ceil_power_of_two(17), content="32")
  debug_inspect(@math3d.MathUtils::ceil_power_of_two(1024), content="1024")
  debug_inspect(@math3d.MathUtils::ceil_power_of_two(1023), content="1024")
  debug_inspect(@math3d.MathUtils::floor_power_of_two(1), content="1")
  debug_inspect(@math3d.MathUtils::floor_power_of_two(17), content="16")
  debug_inspect(@math3d.MathUtils::floor_power_of_two(16), content="16")
}

///|
test "MathUtils seededRandom 与 three.js Mulberry32 位级一致" {
  // 期望值由 JS ToInt32/imul/>>> 语义参照实现生成(python 按位模拟)
  debug_inspect(
    @math3d.MathUtils::seeded_random_with(1234567),
    content="0.6074679309967905",
  )
  debug_inspect(@math3d.MathUtils::seeded_random(), content="0.19144689152017236")
  debug_inspect(@math3d.MathUtils::seeded_random(), content="0.43751312675885856")
  debug_inspect(@math3d.MathUtils::seeded_random(), content="0.3372786734253168")
  // 换种子重置序列
  debug_inspect(
    @math3d.MathUtils::seeded_random_with(42),
    content="0.6011037519201636",
  )
}

///|
test "MathUtils setQuaternionFromProperEuler:XYX 中间角绕 Y" {
  let deg = @math3d.MathUtils::deg_to_rad(90.0)
  let q = @math3d.MathUtils::set_quaternion_from_proper_euler(
    0.0,
    deg,
    0.0,
    XYX,
  )
  // XYX:首末角绕 X,中间角绕 Y;q = (0, sin45, 0, cos45)
  debug_inspect(
    q.x.abs() < 0.0000001 &&
    (q.y - 0.7071067811865476).abs() < 0.0000001 &&
    q.z.abs() < 0.0000001 &&
    (q.w - 0.7071067811865476).abs() < 0.0000001,
    content="true",
  )
  // 与绕 Y 轴 90° 的 from_axis_angle 同四元数
  let expected_q = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_y(),
    1.5707963267948966,
  )
  debug_inspect(q.dot(expected_q).abs() > 0.999999, content="true")
  // 作用于 +X:绕 Y 90° 应得 -Z
  let p = q.apply(@math3d.Vector3::unit_x())
  debug_inspect(
    p.x.abs() < 0.0000001 &&
    p.y.abs() < 0.0000001 &&
    (p.z + 1.0).abs() < 0.0000001,
    content="true",
  )
}
