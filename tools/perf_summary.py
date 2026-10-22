"""Summarise STATS lines from the debug runner (--stats) read on stdin.
Usage: godot ... -- --stats ... | python tools/perf_summary.py [label]
Skips the first 6 seconds (loading/intro)."""
import re, sys, statistics as st
label = sys.argv[1] if len(sys.argv) > 1 else ""
rows = []
for line in sys.stdin:
    m = re.search(r"STATS t=(\d+) fps=(\d+) avg_ms=([\d.]+) worst_ms=([\d.]+) cpu_proc_ms=([\d.]+) cpu_phys_ms=([\d.]+) gpu_ms=([\d.]+) mem_mb=([\d.]+) vmem_mb=([\d.]+) objects=(\d+) draw_calls=(\d+) prims=(\d+) race_t=([\d.]+)", line)
    if m:
        v = [float(x) for x in m.groups()]
        if v[0] > 6 and v[12] > 0:
            rows.append(v)
if not rows:
    print(label, "no samples"); sys.exit(1)
col = lambda i: [r[i] for r in rows]
p95 = lambda xs: sorted(xs)[int(len(xs) * 0.95) - 1]
print(f"{label}: n={len(rows)}s fps min/med {min(col(1)):.0f}/{st.median(col(1)):.0f} | worst frame max {max(col(3)):.1f}ms, >20ms in {sum(x > 20 for x in col(3))}s | "
      f"cpu process {st.median(col(4)):.2f}ms phys {st.median(col(5)):.2f}ms | gpu med {st.median(col(6)):.2f} p95 {p95(col(6)):.2f}ms | "
      f"draws med {st.median(col(10)):.0f} p95 {p95(col(10)):.0f} | prims med {st.median(col(11))/1e3:.0f}k p95 {p95(col(11))/1e3:.0f}k | mem {min(col(7)):.0f}-{max(col(7)):.0f}MB vram {max(col(8)):.0f}MB")
