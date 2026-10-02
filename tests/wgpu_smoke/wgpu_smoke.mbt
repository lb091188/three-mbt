// wgpu-mbt 地基冒烟:验证静态库自动下载链接与 headless
// adapter/device/queue 创建链路(CI 无显示环境可跑)。

///|
test "headless device 创建与原生库状态" {
  @wgpu_mbt.require_native()
  inspect(@wgpu_mbt.native_static_linked(), content="true")
  inspect(@wgpu_mbt.get_version() > 0, content="true")
  let device_created : Ref[Bool] = Ref(false)
  @wgpu_mbt.with_default_device_queue_sync(
    fn(
        _instance : @wgpu_mbt.Instance,
        _device : @wgpu_mbt.Device,
        _queue : @wgpu_mbt.Queue,
      ) -> Unit {
      device_created.val = true
    },
  ) catch {
    _ => device_created.val = false
  }
  // 回调被调即 adapter/device/queue 全部创建成功
  inspect(device_created.val, content="true")
}
