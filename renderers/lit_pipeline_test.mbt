// renderers 包黑盒测试:灯光挂接与世界空间换算。

test "attach_ambient_light:光色与强度入场景集合" {
  let scene = @core.Scene::new()
  @renderers.attach_ambient_light(
    scene,
    @lights.AmbientLight::new(color=@math3d.Color::red(), intensity=0.5),
  )
  let a = scene.lights.ambient.unwrap()
  debug_inspect(a.color.equals(@math3d.Color::red()), content="true")
  debug_inspect(a.intensity == 0.5, content="true")
}

test "attach_directional_light:入射方向为 position-target 归一化" {
  let scene = @core.Scene::new()
  let light = @lights.DirectionalLight::new(intensity=2.0)
  light.obj.position = @math3d.Vector3::new(3.0, 4.0, 0.0)
  // target 默认在原点
  @renderers.attach_directional_light(scene, light)
  let d = scene.lights.directional.unwrap()
  debug_inspect(d.intensity == 2.0, content="true")
  debug_inspect((d.direction.x - 0.6).abs() < 0.0000001, content="true")
  debug_inspect((d.direction.y - 0.8).abs() < 0.0000001, content="true")
  debug_inspect(d.direction.z.abs() < 0.0000001, content="true")
}

test "attach_point_light:世界位置与衰减参数入集合" {
  let scene = @core.Scene::new()
  let light = @lights.PointLight::new(intensity=5.0, distance=10.0, decay=1.5)
  light.obj.position = @math3d.Vector3::new(1.0, 2.0, 3.0)
  @renderers.attach_point_light(scene, light)
  let p = scene.lights.point.unwrap()
  debug_inspect(
    p.position.equals(@math3d.Vector3::new(1.0, 2.0, 3.0)),
    content="true",
  )
  debug_inspect(p.intensity == 5.0, content="true")
  debug_inspect(p.distance == 10.0, content="true")
  debug_inspect(p.decay == 1.5, content="true")
}

test "SceneLights::empty:三类光源皆空,新场景默认空集合" {
  let lights = @core.SceneLights::empty()
  debug_inspect(lights.ambient is None, content="true")
  debug_inspect(lights.directional is None, content="true")
  debug_inspect(lights.point is None, content="true")
  let scene = @core.Scene::new()
  debug_inspect(scene.lights.ambient is None, content="true")
  debug_inspect(scene.lights.directional is None, content="true")
  debug_inspect(scene.lights.point is None, content="true")
}
