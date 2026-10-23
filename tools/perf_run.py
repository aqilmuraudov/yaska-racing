"""Run a seeded autopilot race with --stats and summarise frame/GPU/memory numbers.

Usage: python tools/perf_run.py [preset] [seconds] [extra godot user args...]
Desktop proxy only (Mobile renderer, 1600x720). Not a phone measurement.
"""
import re
import statistics
import subprocess
import sys

GODOT = "C:/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe"


def main() -> None:
    preset = sys.argv[1] if len(sys.argv) > 1 else "medium"
    seconds = sys.argv[2] if len(sys.argv) > 2 else "75"
    extra = sys.argv[3:]
    cmd = [GODOT, "--path", ".", "--rendering-method", "mobile", "--resolution", "1600x720",
           "--", "--race", "--autopilot", "--seed=5", "--stats", "--graphics=" + preset,
           "--quit-after=" + seconds] + extra
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    rows = []
    for line in out.splitlines():
        if not line.startswith("STATS"):
            continue
        d = dict(re.findall(r"(\w+)=([-\d.]+)", line))
        if float(d.get("race_t", 0)) <= 0.5:
            continue  # skip loading / countdown
        rows.append({k: float(v) for k, v in d.items()})
    if not rows:
        print(out[-3000:])
        sys.exit(1)

    def med(key):
        return statistics.median(r[key] for r in rows)

    def p95(key):
        vals = sorted(r[key] for r in rows)
        return vals[min(len(vals) - 1, int(len(vals) * 0.95))]

    print(f"preset={preset} samples={len(rows)}")
    print(f"fps med={med('fps'):.0f}  avg_ms med={med('avg_ms'):.2f}  worst_ms max={max(r['worst_ms'] for r in rows):.1f}"
          f"  frames>20ms(sec-buckets)={sum(1 for r in rows if r['worst_ms'] > 20)}")
    print(f"draw_calls med={med('draw_calls'):.0f} p95={p95('draw_calls'):.0f}  prims med={med('prims')/1000:.0f}k")
    print(f"gpu_ms med={med('gpu_ms'):.2f} p95={p95('gpu_ms'):.2f}  cpu proc={med('cpu_proc_ms'):.2f} phys={med('cpu_phys_ms'):.2f}")
    print(f"static mem {min(r['mem_mb'] for r in rows):.0f}-{max(r['mem_mb'] for r in rows):.0f} MB  vmem med={med('vmem_mb'):.0f} MB  objects={med('objects'):.0f}")


if __name__ == "__main__":
    main()
