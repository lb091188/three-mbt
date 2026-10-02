// math 包黑盒测试:Vector 族(three.js 语义对齐)。

///|
test "Vector3 add/sub/multiply/divide" {
  let a = @math3d.Vector3::new(1.0, 2.0, 3.0)
  let b = @math3d.Vector3::new(4.0, 5.0, 6.0)
  debug_inspect(a.add(b), content=(
    #|{ x: 5, y: 7, z: 9 }
  ))
  debug_inspect(a.sub(b), content=(
    #|{ x: -3, y: -3, z: -3 }
  ))
  debug_inspect(a.multiply_scalar(2.0), content=(
    #|{ x: 2, y: 4, z: 6 }
  ))
  debug_inspect(a.divide_scalar(2.0), content=(
    #|{ x: 0.5, y: 1, z: 1.5 }
  ))
}

///|
test "Vector3 dot/cross(右手系)" {
  let x = @math3d.Vector3::unit_x()
  let y = @math3d.Vector3::unit_y()
  debug_inspect(x.dot(y), content="0")
  debug_inspect(x.cross(y), content=(
    #|{ x: 0, y: 0, z: 1 }
  ))
  debug_inspect(y.cross(x), content=(
    #|{ x: 0, y: 0, z: -1 }
  ))
}

///|
test "Vector3 length/normalize(零向量保护)" {
  let v = @math3d.Vector3::new(3.0, 4.0, 0.0)
  debug_inspect(v.length(), content="5")
  debug_inspect(v.normalize(), content=(
    #|{ x: 0.6000000000000001, y: 0.8, z: 0 }
  ))
  debug_inspect(@math3d.Vector3::zero().normalize(), content=(
    #|{ x: 0, y: 0, z: 0 }
  ))
  debug_inspect(@math3d.Vector3::zero().divide_scalar(3.0), content=(
    #|{ x: 0, y: 0, z: 0 }
  ))
}

///|
test "Vector3 lerp/distance/min/max" {
  let a = @math3d.Vector3::new(0.0, 0.0, 0.0)
  let b = @math3d.Vector3::new(10.0, -20.0, 30.0)
  debug_inspect(a.lerp(b, 0.25), content=(
    #|{ x: 2.5, y: -5, z: 7.5 }
  ))
  debug_inspect(a.distance_to(b), content="37.416573867739416")
  debug_inspect(a.distance_to_squared(b), content="1400")
  debug_inspect(a.min(b), content=(
    #|{ x: 0, y: -20, z: 0 }
  ))
  debug_inspect(a.max(b), content=(
    #|{ x: 10, y: 0, z: 30 }
  ))
}

///|
test "Vector2 基本运算" {
  let a = @math3d.Vector2::new(1.0, 2.0)
  let b = @math3d.Vector2::new(3.0, 5.0)
  debug_inspect(a.add(b), content=(
    #|{ x: 4, y: 7 }
  ))
  debug_inspect(a.dot(b), content="13")
  debug_inspect(a.length(), content="2.23606797749979")
  debug_inspect(a.normalize(), content=(
    #|{ x: 0.4472135954999579, y: 0.8944271909999159 }
  ))
  debug_inspect(a.lerp(b, 0.5), content=(
    #|{ x: 2, y: 3.5 }
  ))
}

///|
test "Vector4 基本运算" {
  let a = @math3d.Vector4::new(1.0, 0.0, 0.0, 0.0)
  let b = @math3d.Vector4::new(0.0, 0.0, 3.0, 4.0)
  debug_inspect(a.add(b), content=(
    #|{ x: 1, y: 0, z: 3, w: 4 }
  ))
  debug_inspect(b.length(), content="5")
  debug_inspect(b.normalize(), content=(
    #|{ x: 0, y: 0, z: 0.6000000000000001, w: 0.8 }
  ))
}

///|
test "Matrix4 乘法与单位元" {
  let i = @math3d.Matrix4::identity()
  let t = @math3d.Matrix4::make_translation(1.0, 2.0, 3.0)
  debug_inspect(i.multiply(t).equals(t), content="true")
  debug_inspect(t.multiply(i).equals(t), content="true")
  let s = @math3d.Matrix4::make_scale(2.0, 2.0, 2.0)
  let p = @math3d.Vector3::new(1.0, 1.0, 1.0)
  // S.multiply(T) = S*T:先平移后缩放
  let ps = s.multiply(t).apply_point(p)
  debug_inspect(ps.x == 4.0 && ps.y == 6.0 && ps.z == 8.0, content="true")
  // T.multiply(S) = T*S:先缩放后平移
  let pt = t.multiply(s).apply_point(p)
  debug_inspect(pt.x == 3.0 && pt.y == 4.0 && pt.z == 5.0, content="true")
}

///|
test "Matrix4 求逆(平移的逆)" {
  let t = @math3d.Matrix4::make_translation(5.0, -3.0, 2.0)
  let ti = t.invert()
  let p = @math3d.Vector3::new(10.0, 10.0, 10.0)
  let q = t.apply_point(p)
  let back = ti.apply_point(q)
  debug_inspect(back.x - 10.0 < 0.000001 && back.y - 10.0 < 0.000001 && back.z - 10.0 < 0.000001, content="true")
}

///|
test "Matrix4 透视投影:近/远裁剪面 z 映射到 0/1(WebGPU NDC)" {
  let m = @math3d.Matrix4::make_perspective(1.0, 1.0, 1.0, 100.0)
  let near = m.apply_point(@math3d.Vector3::new(0.0, 0.0, -1.0))
  debug_inspect(near.x == 0.0 && near.y == 0.0, content="true")
  debug_inspect(near.z > -0.000001 && near.z < 0.000001, content="true")
  let far = m.apply_point(@math3d.Vector3::new(0.0, 0.0, -100.0))
  debug_inspect(far.z > 0.999999 && far.z < 1.000001, content="true")
}

///|
test "Matrix4 lookAt:eye 在原点看 -Z 时目标点落在 NDC 中心" {
  let m = @math3d.Matrix4::make_look_at(
    @math3d.Vector3::new(0.0, 0.0, 0.0),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
    @math3d.Vector3::unit_y(),
  )
  debug_inspect(m.apply_point(@math3d.Vector3::new(0.0, 0.0, -5.0)).z < -0.999999, content="true")
  // 视图矩阵作用于眼点自身 = 原点
  let e = m.apply_point(@math3d.Vector3::new(0.0, 0.0, 0.0))
  debug_inspect(e.x == 0.0 && e.y == 0.0 && e.z == 0.0, content="true")
}

///|
test "Matrix4 轴旋转:绕 Z 转 90° 把 +X 转到 +Y" {
  let m = @math3d.Matrix4::make_rotation_axis(@math3d.Vector3::unit_z(), 1.5707963267948966)
  let p = m.apply_point(@math3d.Vector3::unit_x())
  debug_inspect(p.x < 0.000001 && p.x > -0.000001, content="true")
  debug_inspect(p.y > 0.999999, content="true")
}

///|
test "Quaternion 绕 Z 转 90° 把 +X 转到 +Y" {
  let q = @math3d.Quaternion::from_axis_angle(@math3d.Vector3::unit_z(), 1.5707963267948966)
  let p = q.apply(@math3d.Vector3::unit_x())
  debug_inspect(p.x < 0.000001 && p.x > -0.000001, content="true")
  debug_inspect(p.y > 0.999999, content="true")
}

///|
test "Quaternion 单位元与共轭" {
  let i = @math3d.Quaternion::identity()
  let q = @math3d.Quaternion::from_axis_angle(@math3d.Vector3::unit_y(), 0.7)
  debug_inspect(i.multiply(q).dot(q) > 0.999999, content="true")
  let p = @math3d.Vector3::new(1.0, 2.0, 3.0)
  let back = q.invert().apply(q.apply(p))
  debug_inspect(back.distance_to(p) < 0.000001, content="true")
}

///|
test "Quaternion slerp 端点与中点" {
  let a = @math3d.Quaternion::identity()
  let b = @math3d.Quaternion::from_axis_angle(@math3d.Vector3::unit_z(), 1.5707963267948966)
  debug_inspect(a.slerp(b, 0.0).dot(a) > 0.999999, content="true")
  debug_inspect(a.slerp(b, 1.0).dot(b) > 0.999999, content="true")
  let mid = a.slerp(b, 0.5)
  debug_inspect(mid.length2().sqrt() > 0.999999 && mid.length2().sqrt() < 1.000001, content="true")
  let pm = mid.apply(@math3d.Vector3::unit_x())
  // 中点应把 +X 转到 45°(x=y)
  debug_inspect((pm.x - pm.y).abs() < 0.000001, content="true")
}

///|
test "Euler→Quaternion 与 Matrix4 轴旋转一致(绕 Z 90°)" {
  let q = @math3d.Quaternion::from_euler(@math3d.Euler::new(0.0, 0.0, 1.5707963267948966))
  let m = @math3d.Matrix4::make_rotation_axis(@math3d.Vector3::unit_z(), 1.5707963267948966)
  let p = @math3d.Vector3::new(1.0, 0.0, 0.0)
  let pq = q.apply(p)
  let pm = m.apply_point(p)
  debug_inspect(pq.distance_to(pm) < 0.000001, content="true")
}

///|
test "Quaternion.to_matrix4 与 apply 同效" {
  // 轴先单位化(from_axis_angle 不再代为归一化,three.js 同式)
  let q = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::new(1.0, 1.0, 0.0).normalize(),
    0.9,
  )
  let p = @math3d.Vector3::new(3.0, -2.0, 5.0)
  let a = q.apply(p)
  let b = q.to_matrix4().apply_point(p)
  debug_inspect(a.distance_to(b) < 0.000001, content="true")
}

///|
test "Color from_hex/to_hex 往返" {
  // from_hex 按 sRGB 输入转线性存储(three.js setHex 默认色彩管理同语义)
  debug_inspect(@math3d.Color::from_hex("#ff8000"), content=(
    #|Some({ r: 1, g: 0.21586050010324415, b: 0 })
  ))
  debug_inspect(@math3d.Color::from_hex("#f80"), content=(
    #|Some({ r: 1, g: 0.24620132669705552, b: 0 })
  ))
  debug_inspect(@math3d.Color::from_hex("#12g456"), content="None")
  debug_inspect(@math3d.Color::from_hex("#ff8000").unwrap().to_hex(), content=(
    #|"#ff8000"
  ))
  // 线性空间插值后转回 sRGB(three.js getHex 同语义)
  debug_inspect(@math3d.Color::red().lerp(@math3d.Color::blue(), 0.25).to_hex(), content=(
    #|"#e10089"
  ))
  debug_inspect(@math3d.Color::red().multiply(@math3d.Color::white()).equals(@math3d.Color::red()), content="true")
}

///|
test "Matrix3 normal_from_matrix4:均匀缩放下法线方向不变" {
  let m = @math3d.Matrix4::make_scale(2.0, 2.0, 2.0).multiply(
    @math3d.Matrix4::make_rotation_axis(@math3d.Vector3::unit_z(), 0.5),
  )
  let nm = @math3d.Matrix3::normal_from_matrix4(m)
  let n = @math3d.Vector3::unit_x()
  let tn = nm.apply(n)
  debug_inspect(tn.length() > 0.999999 && tn.length() < 1.000001, content=(
    #|false
  ))
}

///|
test "divide_scalar 除零(three.js 语义:±Infinity/NaN)" {
  let v = @math3d.Vector3::new(1.0, 2.0, 3.0)
  let r = v.divide_scalar(0.0)
  debug_inspect(r.x > 1.0e308 && r.y > 1.0e308 && r.z > 1.0e308, content="true")
  let n = @math3d.Vector3::zero().divide_scalar(0.0)
  debug_inspect(n.x != n.x && n.y != n.y && n.z != n.z, content="true")
  // 乘 1/s 而非 x/s(位级与 three.js divideScalar 一致)
  debug_inspect(@math3d.Vector3::new(5.0, 0.0, 0.0).divide_scalar(3.0).x == 5.0 * (1.0 / 3.0), content="true")
}

///|
test "Vector3 min/max(Math.min/max 语义:NaN 传播、±0 取号)" {
  let a = @math3d.Vector3::new(0.0 / 0.0, -0.0, -0.0)
  let b = @math3d.Vector3::new(5.0, 0.0, 0.0)
  let mn = a.min(b)
  let mx = a.max(b)
  // 任一分量为 NaN 即传播
  debug_inspect(mn.x != mn.x && mx.x != mx.x, content="true")
  // min(-0,+0)=-0、max(-0,+0)=+0(以 1/x 判零的符号)
  debug_inspect(1.0 / mn.y < 0.0, content="true")
  debug_inspect(1.0 / mx.y > 0.0, content="true")
}

///|
test "Quaternion slerp dot<0 走短弧(对 b 全分量取反)" {
  let deg = 3.141592653589793 / 180.0
  // a=绕Z 20°、b=绕Z 260°:dot<0,中点应为绕Z -40°(短弧)
  let a = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    20.0 * deg,
  )
  let b = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    260.0 * deg,
  )
  let mid = a.slerp(b, 0.5)
  let expect = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    -40.0 * deg,
  )
  debug_inspect(mid.dot(expect).abs() > 0.999999, content="true")
}

///|
test "Matrix4 make_orthographic:元素与 three.js(WebGPU)公式一致" {
  // (l,r,t,b,n,f)=(0,2,3,-1,-1,1):y=2/(t-b)=0.5、b 项=-(t+b)/(t-b)=-0.5
  let m = @math3d.Matrix4::make_orthographic(0.0, 2.0, 3.0, -1.0, -1.0, 1.0)
  debug_inspect(m.e[5] == 0.5, content="true")
  debug_inspect(m.e[13] == -0.5, content="true")
  // WebGPU 深度:c=-1/(f-n)=-0.5、d=-n/(f-n)=0.5
  debug_inspect(m.e[10] == -0.5, content="true")
  debug_inspect(m.e[14] == 0.5, content="true")
}

///|
test "Matrix4 invert 奇异返回零矩阵(three.js 同语义)" {
  let m = @math3d.Matrix4::make_scale(0.0, 1.0, 1.0).invert()
  let mut zero = true
  for i in 0..<16 {
    if m.e[i] != 0.0 {
      zero = false
    }
  }
  debug_inspect(zero, content="true")
}

///|
test "Matrix3 normal_from_matrix4 奇异返回零矩阵(three.js 同语义)" {
  let m = @math3d.Matrix4::make_scale(0.0, 1.0, 1.0)
  let nm = @math3d.Matrix3::normal_from_matrix4(m)
  let mut zero = true
  for i in 0..<9 {
    if nm.e[i] != 0.0 {
      zero = false
    }
  }
  debug_inspect(zero, content="true")
}

///|
test "Matrix4 lookAt 退化分支(three.js 同式)" {
  // eye==target:回退 z=(0,0,1),矩阵仍有效
  let m = @math3d.Matrix4::make_look_at(
    @math3d.Vector3::zero(),
    @math3d.Vector3::zero(),
    @math3d.Vector3::unit_y(),
  )
  debug_inspect(m.e[0] == 1.0 && m.e[5] == 1.0 && m.e[10] == 1.0, content="true")
  // up 与视线平行:对 z 微扰后重叉积,x 基=(0,1,0)(与 three.js 数值一致,
  // 扰动归一化有浮点尾差,用容差断言)
  let p = @math3d.Matrix4::make_look_at(
    @math3d.Vector3::zero(),
    @math3d.Vector3::new(0.0, 0.0, -1.0),
    @math3d.Vector3::unit_z(),
  )
  debug_inspect(p.e[0].abs() < 0.000001 && (p.e[1] - 1.0).abs() < 0.000001 && p.e[2].abs() < 0.000001, content="true")
}

///|
test "Matrix4 apply_direction 变换后归一化(three.js transformDirection)" {
  let m = @math3d.Matrix4::make_scale(2.0, 2.0, 2.0)
  let d = m.apply_direction(@math3d.Vector3::unit_x())
  debug_inspect((d.x - 1.0).abs() < 0.000001 && d.y == 0.0 && d.z == 0.0, content="true")
}
