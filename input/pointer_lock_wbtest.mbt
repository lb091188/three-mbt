// PointerLock 白盒测:纯逻辑部分(差分/回声过滤/锚点更新/参数防御)。
// 直构 struct 字面量,零 FFI —— wasm/js 目标同样可跑;
// attach/acquire 走真 X,由 gameapp 真机验收覆盖,不入单测。

///| 直构实例:dpy/win 置 0(纯函数路径不触 X)。
fn pl_fixture(w : Int, h : Int) -> PointerLock {
  { dpy: 0UL, win: 0UL, cx: w / 2, cy: h / 2, locked: false }
}

///|
test "attach: 参数防御(零 display/零窗口/非正尺寸 → None,不触 FFI)" {
  assert_true(PointerLock::attach(0UL, 1U, 800, 600) is None)
  assert_true(PointerLock::attach(1UL, 0U, 800, 600) is None)
  assert_true(PointerLock::attach(1UL, 1U, 0, 600) is None)
  assert_true(PointerLock::attach(1UL, 1U, 800, -1) is None)
}

///|
test "delta: 中心回声过滤与四向差分" {
  let pl = pl_fixture(800, 600)
  assert_true(!pl.is_locked())
  assert_true(pl.delta(400.0, 300.0) is None) // 回中回声
  assert_eq(pl.delta(450.0, 300.0), Some((50.0, 0.0)))
  assert_eq(pl.delta(350.0, 300.0), Some((-50.0, 0.0)))
  assert_eq(pl.delta(400.0, 340.0), Some((0.0, 40.0)))
  assert_eq(pl.delta(400.0, 260.0), Some((0.0, -40.0)))
  assert_eq(pl.delta(388.5, 311.5), Some((-11.5, 11.5)))
}

///|
test "update_size: 锚点跟随,非法尺寸不动" {
  let pl = pl_fixture(800, 600)
  pl.update_size(1000, 600)
  assert_true(pl.delta(500.0, 300.0) is None) // 新中心即回声
  assert_eq(pl.delta(600.0, 300.0), Some((100.0, 0.0)))
  pl.update_size(0, -5) // 非法 → 保持
  assert_eq(pl.delta(600.0, 300.0), Some((100.0, 0.0)))
}

///|
test "release 幂等: 未 acquire 直接 release 不炸且不触 FFI" {
  let pl = pl_fixture(800, 600)
  pl.release() // locked=false → 直接返回
  pl.release()
  assert_true(!pl.is_locked())
}
