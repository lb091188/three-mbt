// core 包黑盒测试:场景图与相机。

///|
test "Object3D 层级世界矩阵:父平移+子平移叠加" {
  let parent = @core.Object3D::new()
  parent.position = @math3d.Vector3::new(1.0, 0.0, 0.0)
  let child = @core.Object3D::new()
  child.position = @math3d.Vector3::new(0.0, 1.0, 0.0)
  parent.add(child)
  parent.update_matrix_world(false)
  let wp = child.world_position()
  debug_inspect(wp.x - 1.0 < 0.000001 && wp.y - 1.0 < 0.000001 && wp.z < 0.000001, content="true")
}

///|
test "Object3D compose:T*R*S(先缩放旋转后平移)" {
  let o = @core.Object3D::new()
  o.position = @math3d.Vector3::new(10.0, 0.0, 0.0)
  o.rotation = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    1.5707963267948966,
  )
  o.scale = @math3d.Vector3::new(2.0, 2.0, 2.0)
  o.update_matrix()
  // 局部点 (1,0,0):缩放→(2,0,0),旋转→(0,2,0),平移→(10,2,0)
  let p = o.matrix.apply_point(@math3d.Vector3::unit_x())
  debug_inspect(p.x - 10.0 < 0.000001 && p.y - 2.0 < 0.000001 && p.z < 0.000001, content="true")
}

///|
test "Object3D add/remove 父子互斥" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let c = @core.Object3D::new()
  a.add(b)
  c.add(b) // 应先把 b 从 a 摘除
  debug_inspect(a.children.length(), content="0")
  debug_inspect(c.children.length(), content="1")
  c.remove(b)
  debug_inspect(c.children.length(), content="0")
}

///|
test "Matrix4↔Quaternion 往返" {
  let q1 = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::new(1.0, 1.0, 0.0).normalize(),
    0.9,
  )
  let q2 = q1.to_matrix4().to_quaternion()
  debug_inspect(q1.dot(q2).abs() > 0.999999, content="true")
}

///|
test "PerspectiveCamera look_at:视图矩阵作用于眼点为零" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.5, 0.1, 100.0)
  let eye = @math3d.Vector3::new(3.0, 4.0, 5.0)
  cam.look_at(eye, @math3d.Vector3::zero())
  let v = cam.view_matrix()
  let e = v.apply_point(eye)
  debug_inspect(e.x < 0.000001 && e.x > -0.000001, content="true")
  debug_inspect(e.y < 0.000001 && e.y > -0.000001, content="true")
  debug_inspect(e.z < 0.000001 && e.z > -0.000001, content="true")
}

///|
test "PerspectiveCamera 投影:近裁剪点映射到 WebGPU NDC z≈0" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.0, 1.0, 100.0)
  cam.look_at(
    @math3d.Vector3::new(0.0, 0.0, 1.0),
    @math3d.Vector3::zero(),
  )
  let v = cam.view_matrix()
  let p = cam.projection_matrix.apply_point(
    v.apply_point(@math3d.Vector3::zero()),
  )
  debug_inspect(p.z > -0.000001 && p.z < 0.000001, content="true")
}

///|
test "Scene 基本结构" {
  let s = @core.Scene::new()
  let o = @core.Object3D::new()
  s.add(o)
  s.background = Some(@math3d.Color::from_hex("#101010").unwrap())
  s.update_matrix_world()
  debug_inspect(s.root.children.length(), content="1")
  debug_inspect(s.background.unwrap().to_hex() == "#101010", content="true")
}

///|
test "Object3D add 重复子节点移动到末尾(three.js removeFromParent+push)" {
  let a = @core.Object3D::new()
  let b = @core.Object3D::new()
  let c = @core.Object3D::new()
  a.add(b)
  a.add(c)
  a.add(b) // b 已是子节点:摘除后重新追加,移到 children 末尾
  debug_inspect(a.children.length(), content="2")
  debug_inspect(a.children[0].id == c.id && a.children[1].id == b.id, content="true")
}

///|
test "world_position 自动沿父链更新(three.js getWorldPosition)" {
  let parent = @core.Object3D::new()
  let child = @core.Object3D::new()
  parent.add(child)
  // 不手动 update_matrix_world 也应反映最新变换
  parent.position = @math3d.Vector3::new(2.0, 0.0, 0.0)
  let wp = child.world_position()
  debug_inspect((wp.x - 2.0).abs() < 0.000001 && wp.y.abs() < 0.000001 && wp.z.abs() < 0.000001, content="true")
}

///|
test "view_matrix 剔除相机缩放(glTF 一致,three.js Camera.updateMatrixWorld)" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.0, 0.1, 100.0)
  cam.look_at(@math3d.Vector3::new(0.0, 0.0, 5.0), @math3d.Vector3::zero())
  cam.obj.scale = @math3d.Vector3::new(2.0, 2.0, 2.0)
  let v = cam.view_matrix()
  debug_inspect((v.max_scale_on_axis() - 1.0).abs() < 0.000001, content="true")
}

///|
test "look_at 挂在带旋转父节点下世界姿态不变" {
  let parent = @core.Object3D::new()
  parent.rotation = @math3d.Quaternion::from_axis_angle(
    @math3d.Vector3::unit_z(),
    1.5707963267948966,
  )
  let cam = @core.PerspectiveCamera::new(60.0, 1.0, 0.1, 100.0)
  parent.add(cam.obj)
  cam.look_at(@math3d.Vector3::new(5.0, 0.0, 0.0), @math3d.Vector3::zero())
  let v = cam.view_matrix()
  // 世界位置=eye:视图矩阵作用于 eye 得原点
  let e = v.apply_point(@math3d.Vector3::new(5.0, 0.0, 0.0))
  debug_inspect(e.x.abs() < 0.000001 && e.y.abs() < 0.000001 && e.z.abs() < 0.000001, content="true")
  // 世界朝向看 target:目标点落在相机正前方(x/y≈0,z<0)
  let t = v.apply_point(@math3d.Vector3::zero())
  debug_inspect(t.x.abs() < 0.000001 && t.y.abs() < 0.000001 && t.z < 0.0, content="true")
}

///|
test "PerspectiveCamera 投影:远裁剪点映射到 WebGPU NDC z≈1" {
  let cam = @core.PerspectiveCamera::new(60.0, 1.0, 1.0, 100.0)
  cam.look_at(@math3d.Vector3::new(0.0, 0.0, 1.0), @math3d.Vector3::zero())
  let v = cam.view_matrix()
  let p = cam.projection_matrix.apply_point(
    v.apply_point(@math3d.Vector3::new(0.0, 0.0, -99.0)),
  )
  debug_inspect(p.z > 0.999999 && p.z < 1.000001, content="true")
}

///|
test "Material Basic 不受光:kind 判定与 emissive 恒黑" {
  let m = @core.Material::basic(@math3d.Color::red())
  debug_inspect(m.is_basic(), content="true")
  debug_inspect(m.is_lambert() || m.is_phong(), content="false")
  debug_inspect(m.lit(), content="false")
  debug_inspect(m.emissive.equals(@math3d.Color::black()), content="true")
}

///|
test "Material Lambert 构造:kind=1 受光,color/emissive 保存" {
  let c = @math3d.Color::from_hex("#ff8888").unwrap()
  let e = @math3d.Color::from_hex("#222222").unwrap()
  let m = @core.Material::lambert(c, e)
  debug_inspect(m.is_lambert(), content="true")
  debug_inspect(m.is_basic() || m.is_phong(), content="false")
  debug_inspect(m.lit(), content="true")
  debug_inspect(m.color.equals(c) && m.emissive.equals(e), content="true")
}

///|
test "Material Phong 构造:kind=2 受光,color/specular/shininess/emissive 保存" {
  // three.js 默认高光色 #111111(sRGB 输入,from_hex 同 setHex 语义转线性)
  let s = @math3d.Color::from_hex("#111111").unwrap()
  let m = @core.Material::phong(
    @math3d.Color::white(),
    s,
    30.0,
    @math3d.Color::black(),
  )
  debug_inspect(m.is_phong(), content="true")
  debug_inspect(m.is_basic() || m.is_lambert(), content="false")
  debug_inspect(m.lit(), content="true")
  debug_inspect(
    m.color.equals(@math3d.Color::white()) &&
    m.specular.equals(s) &&
    m.emissive.equals(@math3d.Color::black()),
    content="true",
  )
  debug_inspect(m.shininess == 30.0, content="true")
}

///|
test "OrthographicCamera 投影元素:three.js makeOrthographic(WebGPU)同式" {
  // (l,r,t,b,n,f)=(-2,6,4,-1,0.5,10):x=2/(r-l)=0.25、a=-(r+l)/(r-l)=-0.5
  let cam = @core.OrthographicCamera::new(-2.0, 6.0, 4.0, -1.0, 0.5, 10.0)
  let m = cam.projection_matrix
  debug_inspect(m.e[0] == 0.25, content="true")
  debug_inspect(m.e[12] == -0.5, content="true")
  // y=2/(t-b)=0.4、b 项=-(t+b)/(t-b)=-0.6
  debug_inspect(m.e[5] == 0.4, content="true")
  debug_inspect(m.e[13] == -0.6, content="true")
  // WebGPU 深度:c=-1/(f-n)、d=-n/(f-n)
  debug_inspect((m.e[10] - (-1.0 / 9.5)).abs() < 0.000000001, content="true")
  debug_inspect((m.e[14] - (-0.5 / 9.5)).abs() < 0.000000001, content="true")
  debug_inspect(m.e[15] == 1.0, content="true")
}

///|
test "OrthographicCamera 视锥角点映射 NDC 角点,near=0 合法" {
  // near=0 对正交相机合法(three.js 文档明确);相机默认位于原点朝 -z,
  // 世界点 z 取负即相机前方
  let cam = @core.OrthographicCamera::new(-2.0, 2.0, 2.0, -2.0, 0.0, 10.0)
  let near_corner = cam.projection_matrix.apply_point(
    @math3d.Vector3::new(-2.0, -2.0, 0.0),
  )
  debug_inspect((near_corner.x + 1.0).abs() < 0.000001, content="true")
  debug_inspect((near_corner.y + 1.0).abs() < 0.000001, content="true")
  debug_inspect(near_corner.z.abs() < 0.000001, content="true")
  let far_corner = cam.projection_matrix.apply_point(
    @math3d.Vector3::new(2.0, 2.0, -10.0),
  )
  debug_inspect((far_corner.x - 1.0).abs() < 0.000001, content="true")
  debug_inspect((far_corner.y - 1.0).abs() < 0.000001, content="true")
  debug_inspect((far_corner.z - 1.0).abs() < 0.000001, content="true")
}

///|
test "OrthographicCamera 参数变更后 update_projection_matrix 重建" {
  // 构造即算(three.js 构造器尾部调 updateProjectionMatrix)
  let cam = @core.OrthographicCamera::new(-1.0, 1.0, 1.0, -1.0, 0.1, 2000.0)
  debug_inspect(
    (cam.projection_matrix.e[10] - (-1.0 / 1999.9)).abs() < 0.000000001,
    content="true",
  )
  cam.far = 10.0
  cam.update_projection_matrix()
  debug_inspect(
    (cam.projection_matrix.e[10] - (-1.0 / 9.9)).abs() < 0.000000001,
    content="true",
  )
  // 离轴平移改变中心 cx:m[12]=-(r+l)/(r-l)=-1、m[0]=2/(r-l)=0.5
  cam.left = 0.0
  cam.right = 4.0
  cam.update_projection_matrix()
  debug_inspect(
    (cam.projection_matrix.e[12] - (-1.0)).abs() < 0.000000001,
    content="true",
  )
  debug_inspect(
    (cam.projection_matrix.e[0] - 0.5).abs() < 0.000000001,
    content="true",
  )
}
