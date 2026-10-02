// math 包黑盒测试:Vector 族(three.js 语义对齐)。

///|
test "Vector3 add/sub/multiply/divide" {
  let a = @math.Vector3::new(1.0, 2.0, 3.0)
  let b = @math.Vector3::new(4.0, 5.0, 6.0)
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
  let x = @math.Vector3::unit_x()
  let y = @math.Vector3::unit_y()
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
  let v = @math.Vector3::new(3.0, 4.0, 0.0)
  debug_inspect(v.length(), content="5")
  debug_inspect(v.normalize(), content=(
    #|{ x: 0.6, y: 0.8, z: 0 }
  ))
  debug_inspect(@math.Vector3::zero().normalize(), content=(
    #|{ x: 0, y: 0, z: 0 }
  ))
  debug_inspect(@math.Vector3::zero().divide_scalar(3.0), content=(
    #|{ x: 0, y: 0, z: 0 }
  ))
}

///|
test "Vector3 lerp/distance/min/max" {
  let a = @math.Vector3::new(0.0, 0.0, 0.0)
  let b = @math.Vector3::new(10.0, -20.0, 30.0)
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
  let a = @math.Vector2::new(1.0, 2.0)
  let b = @math.Vector2::new(3.0, 5.0)
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
  let a = @math.Vector4::new(1.0, 0.0, 0.0, 0.0)
  let b = @math.Vector4::new(0.0, 0.0, 3.0, 4.0)
  debug_inspect(a.add(b), content=(
    #|{ x: 1, y: 0, z: 3, w: 4 }
  ))
  debug_inspect(b.length(), content="5")
  debug_inspect(b.normalize(), content=(
    #|{ x: 0, y: 0, z: 0.6, w: 0.8 }
  ))
}
