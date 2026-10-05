// AI 子进程扮演者:stdin 收 JSON-L({id,x,y,enemies:[{x,y},...]}),
// 算"最近敌人 + 节流决策",stdout 回 JSON-L({id,fire,throttle,dist})。
// 模拟真实 AI 的一点计算量:遍历敌人找最近(游戏里是 15 敌 + 地形查询)。
const readline = require('readline');
const rl = readline.createInterface({ input: process.stdin, terminal: false });
rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;
  let m;
  try { m = JSON.parse(line); } catch (e) { return; }
  let best = Infinity, bx = 0, by = 0;
  for (const e of m.enemies || []) {
    const d = (e.x - m.x) ** 2 + (e.y - m.y) ** 2;
    if (d < best) { best = d; bx = e.x; by = e.y; }
  }
  const dist = Math.sqrt(best);
  process.stdout.write(JSON.stringify({
    id: m.id,
    fire: dist < 300,
    throttle: dist > 200 ? 1.0 : 0.4,
    dist: Math.round(dist * 10) / 10,
  }) + '\n');
});
