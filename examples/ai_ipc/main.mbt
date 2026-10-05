// 实验 B/C:async.process 在 Windows 首验 + AI 独立进程最小形态。
// B:collect_output 跑 cmd.exe /c echo(证明 spawn/exec/collect);
// C:spawn node aiworker.js(AI 内芯扮演者),stdio JSON-L 行协议,
//    60 次决策往返(33ms 节奏),测 RTT —— D4 多进程方案的时延 datum。
// 子进程回包按管道 FIFO 顺序对齐发送序,游标即 id。

#cfg(platform="windows")
extern "c" fn c_fflush(f : UInt64) -> Int = "fflush"

#cfg(platform="windows")
fn outln(s : String) -> Unit {
  println(s)
  ignore(c_fflush(0))
}

#cfg(platform="windows")
extern "c" fn c_GetTickCount() -> UInt64 = "GetTickCount"

#cfg(platform="windows")
fn now_ms() -> Int64 {
  c_GetTickCount().reinterpret_as_int64()
}

///| 造一条 AI 快照 JSON(id,x,y,8 个敌人)
#cfg(platform="windows")
fn snapshot(id : Int) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"id\":\{id},\"x\":100.0,\"y\":200.0,\"enemies\":[")
  for i in 0..<8 {
    if i > 0 {
      buf.write_string(",")
    }
    let ex = 100.0 + Int::to_double(i) * 50.0
    let ey = 200.0 + Int::to_double((i * 37) % 300) - 150.0
    buf.write_string("{\"x\":\{ex},\"y\":\{ey}}")
  }
  buf.write_string("]}")
  buf.to_string()
}

#cfg(platform="windows")
async fn main {
  // ---- B:collect_output 冒烟 ----
  let (code, out, _err) = @process.collect_output(
    "cmd.exe",
    ["/c", "echo hello-from-child"],
    no_console_window=true,
  )
  let out_s = @utf8.decode(out.binary())
  outln("B collect_output: exit=\{code} out=\{out_s.trim()}")
  // ---- C:spawn + 管道 + 行协议 + RTT ----
  let (child_stdin, writer) = @process.write_to_process()
  let (reader, child_stdout) = @process.read_from_process()
  let (_err_reader, child_stderr) = @process.read_from_process()
  @async.with_task_group(group => {
    let p = @process.spawn(
      group,
      "node",
      ["examples/ai_ipc/aiworker.js"],
      stdin=child_stdin,
      stdout=child_stdout,
      stderr=child_stderr,
      no_console_window=true,
    )
    outln("C spawned: pid=\{p.pid}")
    let n : Ref[Int] = Ref(0)
    let rtt_sum : Ref[Int64] = Ref(0)
    let rtt_min : Ref[Int64] = Ref(1000000000L)
    let rtt_max : Ref[Int64] = Ref(0L)
    let times : Ref[Array[Int64]] = Ref([])
    let cursor : Ref[Int] = Ref(0)
    group.spawn_bg(() => {
      // 回读:按行收,与发送游标对齐
      for _ in 0..<60 {
        match reader.read_until("\n") {
          Some(b) => {
            let line = b
            let idx = cursor.val
            let sent = times.val[idx]
            let rtt = now_ms() - sent
            n.val += 1
            rtt_sum.val += rtt
            if rtt < rtt_min.val {
              rtt_min.val = rtt
            }
            if rtt > rtt_max.val {
              rtt_max.val = rtt
            }
            cursor.val += 1
            if n.val == 1 || n.val == 60 {
              outln("C reply #\{n.val}: \{line.trim()} rtt=\{rtt}ms")
            }
          }
          None => break
        }
      }
    })
    group.spawn_bg(() => {
      // 发送:60 条 @33ms
      for i in 0..<60 {
        times.val.push(now_ms())
        writer.write(snapshot(i) + "\n")
        @async.sleep(33)
      }
      writer.close()
    })
    let exit = p.wait()
    outln(
      "C done: replies=\{n.val}/60 exit=\{exit} rtt avg=\{Int64::to_double(rtt_sum.val) / 60.0}ms min=\{rtt_min.val}ms max=\{rtt_max.val}ms",
    )
  })
  outln("B/C experiment done")
}
