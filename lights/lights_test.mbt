// lights 包黑盒测试:光源数据层默认值、换算与拷贝。

///|
test "五种光源默认构造:color 白、intensity 1" {
  let ambient = @lights.AmbientLight::new()
  debug_inspect(ambient.color.equals(@math3d.Color::white()), content="true")
  debug_inspect(ambient.intensity == 1.0, content="true")
  let directional = @lights.DirectionalLight::new()
  debug_inspect(
    directional.color.equals(@math3d.Color::white()),
    content="true",
  )
  debug_inspect(directional.intensity == 1.0, content="true")
  let point = @lights.PointLight::new()
  debug_inspect(point.color.equals(@math3d.Color::white()), content="true")
  debug_inspect(point.intensity == 1.0, content="true")
  let spot = @lights.SpotLight::new()
  debug_inspect(spot.color.equals(@math3d.Color::white()), content="true")
  debug_inspect(spot.intensity == 1.0, content="true")
  let hemi = @lights.HemisphereLight::new()
  debug_inspect(hemi.color.equals(@math3d.Color::white()), content="true")
  debug_inspect(
    hemi.ground_color.equals(@math3d.Color::white()),
    content="true",
  )
  debug_inspect(hemi.intensity == 1.0, content="true")
}

///|
test "AmbientLight 自定义色与强度" {
  let light = @lights.AmbientLight::new(
    color=@math3d.Color::from_hex("#404040").unwrap(),
    intensity=0.5,
  )
  debug_inspect(light.intensity == 0.5, content="true")
  // #404040: sRGB 0x40=64/255 经 sRGB→线性
  let s = 64.0 / 255.0
  let lin = if s < 0.04045 {
    s * 0.0773993808
  } else {
    @math.pow(s * 0.9478672986 + 0.0521327014, 2.4)
  }
  debug_inspect(
    (light.color.r - lin).abs() < 0.0000001 &&
    (light.color.g - lin).abs() < 0.0000001 &&
    (light.color.b - lin).abs() < 0.0000001,
    content="true",
  )
}

///|
test "PointLight 默认 distance=0、decay=2;power 往返" {
  let light = @lights.PointLight::new()
  debug_inspect(light.distance == 0.0, content="true")
  debug_inspect(light.decay == 2.0, content="true")
  light.intensity = 2.0
  debug_inspect(
    (light.power() - 8.0 * @math.PI).abs() < 0.0000001,
    content="true",
  )
  light.set_power(4.0 * @math.PI)
  debug_inspect(light.intensity == 1.0, content="true")
}

///|
test "SpotLight 默认 angle=π/3、penumbra=0、decay=2;power 往返" {
  let light = @lights.SpotLight::new()
  debug_inspect(light.angle == @math.PI / 3.0, content="true")
  debug_inspect(light.penumbra == 0.0, content="true")
  debug_inspect(light.distance == 0.0, content="true")
  debug_inspect(light.decay == 2.0, content="true")
  light.intensity = 3.0
  debug_inspect(
    (light.power() - 3.0 * @math.PI).abs() < 0.0000001,
    content="true",
  )
  light.set_power(@math.PI)
  debug_inspect(light.intensity == 1.0, content="true")
  let tuned = @lights.SpotLight::new(
    angle=@math.PI / 6.0,
    penumbra=0.8,
    distance=50.0,
    decay=1.5,
  )
  debug_inspect(tuned.angle == @math.PI / 6.0, content="true")
  debug_inspect(tuned.penumbra == 0.8, content="true")
  debug_inspect(tuned.distance == 50.0, content="true")
  debug_inspect(tuned.decay == 1.5, content="true")
}

///|
test "DirectionalLight 默认 position=(0,1,0)、target 为原点独立节点" {
  let light = @lights.DirectionalLight::new()
  debug_inspect(
    light.obj.position.x == 0.0 &&
    light.obj.position.y == 1.0 &&
    light.obj.position.z == 0.0,
    content="true",
  )
  debug_inspect(
    light.target.position.x == 0.0 &&
    light.target.position.y == 0.0 &&
    light.target.position.z == 0.0,
    content="true",
  )
  debug_inspect(light.obj.id != light.target.id, content="true")
}

///|
test "SpotLight/HemisphereLight 默认 position=(0,1,0)" {
  let spot = @lights.SpotLight::new()
  debug_inspect(
    spot.obj.position.equals(@math3d.Vector3::unit_y()),
    content="true",
  )
  let hemi = @lights.HemisphereLight::new()
  debug_inspect(
    hemi.obj.position.equals(@math3d.Vector3::unit_y()),
    content="true",
  )
  // PointLight/AmbientLight 默认在原点
  let point = @lights.PointLight::new()
  debug_inspect(
    point.obj.position.equals(@math3d.Vector3::zero()),
    content="true",
  )
  let ambient = @lights.AmbientLight::new()
  debug_inspect(
    ambient.obj.position.equals(@math3d.Vector3::zero()),
    content="true",
  )
}

///|
test "copy_from 拷字段:PointLight" {
  let src = @lights.PointLight::new(
    color=@math3d.Color::red(),
    intensity=2.0,
    distance=10.0,
    decay=1.0,
  )
  src.obj.position = @math3d.Vector3::new(1.0, 2.0, 3.0)
  src.obj.name = "src"
  let dst = @lights.PointLight::new()
  dst.copy_from(src)
  debug_inspect(dst.color.equals(@math3d.Color::red()), content="true")
  debug_inspect(dst.intensity == 2.0, content="true")
  debug_inspect(dst.distance == 10.0, content="true")
  debug_inspect(dst.decay == 1.0, content="true")
  debug_inspect(dst.obj.position.equals(src.obj.position), content="true")
  debug_inspect(dst.obj.name == "src", content="true")
}

///|
test "copy_from 深拷 target:DirectionalLight/SpotLight(同变换、不同节点)" {
  let src = @lights.DirectionalLight::new(intensity=0.5)
  src.target.position = @math3d.Vector3::new(5.0, 0.0, 0.0)
  let dst = @lights.DirectionalLight::new()
  dst.copy_from(src)
  debug_inspect(dst.intensity == 0.5, content="true")
  debug_inspect(
    dst.target.position.equals(@math3d.Vector3::new(5.0, 0.0, 0.0)),
    content="true",
  )
  debug_inspect(dst.target.id != src.target.id, content="true")
  let s2 = @lights.SpotLight::new(penumbra=0.5)
  s2.target.position = @math3d.Vector3::new(0.0, 0.0, 7.0)
  let d2 = @lights.SpotLight::new()
  d2.copy_from(s2)
  debug_inspect(d2.penumbra == 0.5, content="true")
  debug_inspect(
    d2.target.position.equals(@math3d.Vector3::new(0.0, 0.0, 7.0)),
    content="true",
  )
  debug_inspect(d2.target.id != s2.target.id, content="true")
}

///|
test "HemisphereLight copy_from 拷 ground_color" {
  let src = @lights.HemisphereLight::new(
    sky_color=@math3d.Color::from_hex("#ffffbb").unwrap(),
    ground_color=@math3d.Color::from_hex("#080820").unwrap(),
    intensity=0.8,
  )
  let dst = @lights.HemisphereLight::new()
  dst.copy_from(src)
  debug_inspect(dst.color.equals(src.color), content="true")
  debug_inspect(dst.ground_color.equals(src.ground_color), content="true")
  debug_inspect(dst.intensity == 0.8, content="true")
}

///|
test "光源经 obj 挂入场景并参与世界矩阵" {
  let scene = @core.Scene::new()
  let light = @lights.PointLight::new()
  light.obj.position = @math3d.Vector3::new(0.0, 5.0, 0.0)
  scene.add(light.obj)
  scene.update_matrix_world()
  let wp = light.obj.world_position()
  debug_inspect(
    (wp.x - 0.0).abs() < 0.000001 &&
    (wp.y - 5.0).abs() < 0.000001 &&
    (wp.z - 0.0).abs() < 0.000001,
    content="true",
  )
}

///|
test "DirectionalLight 阴影默认(three.js castShadow=false/mapSize=512/视锥±5)+拷贝" {
  let light = @lights.DirectionalLight::new()
  debug_inspect(light.cast_shadow, content="false")
  debug_inspect(light.shadow.map_size == 512, content="true")
  debug_inspect(light.shadow.bias == 0.0, content="true")
  debug_inspect(light.shadow.camera.left == -5.0, content="true")
  debug_inspect(light.shadow.camera.right == 5.0, content="true")
  debug_inspect(light.shadow.camera.top == 5.0, content="true")
  debug_inspect(light.shadow.camera.bottom == -5.0, content="true")
  debug_inspect(light.shadow.camera.near == 0.5, content="true")
  debug_inspect(light.shadow.camera.far == 500.0, content="true")
  // 开阴影改参数后 copy_from 随批拷贝
  light.cast_shadow = true
  light.shadow.map_size = 1024
  light.shadow.bias = -0.0005
  let dst = @lights.DirectionalLight::new()
  dst.copy_from(light)
  debug_inspect(dst.cast_shadow, content="true")
  debug_inspect(dst.shadow.map_size == 1024, content="true")
  debug_inspect(dst.shadow.bias == -0.0005, content="true")
}
