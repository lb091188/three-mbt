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
    #|{ x: 0.6, y: 0.8, z: 0 }
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
    #|{ x: 0, y: 0, z: 0.6, w: 0.8 }
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
test "Matrix4 透视投影:近裁剪面 z=-near(NDC)" {
  let m = @math3d.Matrix4::make_perspective(1.0, 1.0, 1.0, 100.0)
  let p = @math3d.Vector3::new(0.0, 0.0, -1.0)
  let q = m.apply_point(p)
  debug_inspect(q.x == 0.0 && q.y == 0.0, content="true")
  debug_inspect(q.z > -1.000001 && q.z < -0.999999, content="true")
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
