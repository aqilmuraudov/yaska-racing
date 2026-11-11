"""Measure the real FPS of every map on the phone over USB (no screen work needed).

  python tools/phone_fps.py [--apk _builds/X.apk] [--tracks karabakh,old_city] [--tods day,night] [--seconds 90]

Starts the installed game with the debug runner (an autopilot race, --stats) through
`adb shell am start ... --esa command_line_params`, reads the STATS lines Godot prints
to logcat once a second and reports per map / time of day: average FPS, the 5 % low,
the worst frame, CPU / GPU ms, draw calls. A fresh test profile is used
(--fresh-profile), the owner's profile is not touched. The phone must have USB
debugging on and the screen unlocked (the race renders on the real screen).
"""

import argparse
import re
import statistics
import subprocess
import sys
import time

ADB = r"C:/Tools/AndroidSdk/platform-tools/adb.exe"
PKG = "az.bakuturbo.game"
ACT = PKG + "/com.godot.game.GodotApp"
STATS = re.compile(r"STATS t=\S+ fps=(\d+) avg_ms=([\d.]+) worst_ms=([\d.]+) cpu_proc_ms=([\d.]+) "
                   r"cpu_phys_ms=([\d.]+) gpu_ms=([\d.]+) .*?draw_calls=(\d+) prims=(\d+) race_t=([\d.]+)")


def adb(*a, check=True):
    r = subprocess.run([ADB, *a], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        sys.exit(f"adb {' '.join(a)} failed: {r.stderr.strip()}")
    return r.stdout


def measure(track, tod, seconds):
    adb("shell", "am", "force-stop", PKG)
    adb("logcat", "-c")
    params = ",".join(["--", "--fresh-profile", "--no-login", "--race", "--autopilot", f"--track={track}",
                       f"--tod={tod}", "--laps=1", "--stats", f"--quit-after={seconds + 25}"])
    adb("shell", "am", "start", "-n", ACT, "--esa", "command_line_params", params)
    time.sleep(seconds + 30)
    log = adb("logcat", "-d", "-s", "godot:*")
    adb("shell", "am", "force-stop", PKG)
    rows = [m.groups() for m in STATS.finditer(log)]
    rows = [r for r in rows if float(r[8]) > 3.0]       # racing frames only (after the countdown)
    if not rows:
        return None
    fps = [int(r[0]) for r in rows]
    low = sorted(fps)[max(0, len(fps) // 20)]
    return {"n": len(rows), "fps": statistics.mean(fps), "low5": low, "worst_ms": max(float(r[2]) for r in rows),
            "cpu": statistics.mean(float(r[3]) + float(r[4]) for r in rows),
            "gpu": statistics.mean(float(r[5]) for r in rows), "draws": statistics.mean(int(r[6]) for r in rows)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk")
    ap.add_argument("--tracks", default="seafront_sprint,downtown_towers,old_city,karabakh")
    ap.add_argument("--tods", default="day,night")
    ap.add_argument("--seconds", type=int, default=90)
    a = ap.parse_args()
    devs = [l for l in adb("devices").splitlines()[1:] if l.strip().endswith("device")]
    if not devs:
        sys.exit("no phone: connect it over USB with USB debugging on")
    print("phone:", adb("shell", "getprop", "ro.product.model").strip(), "Android",
          adb("shell", "getprop", "ro.build.version.release").strip())
    if a.apk:
        print(adb("install", "-r", a.apk).strip().splitlines()[-1])
    print(f"{'map':16s} {'tod':6s} {'fps':>5s} {'5%low':>6s} {'worst':>7s} {'cpu':>6s} {'gpu':>6s} {'draws':>6s}")
    for track in a.tracks.split(","):
        for tod in a.tods.split(","):
            r = measure(track, tod, a.seconds)
            if r is None:
                print(f"{track:16s} {tod:6s} no STATS lines (did the race start? screen unlocked?)")
                continue
            print(f"{track:16s} {tod:6s} {r['fps']:5.1f} {r['low5']:6d} {r['worst_ms']:6.1f}ms {r['cpu']:5.1f}ms "
                  f"{r['gpu']:5.1f}ms {r['draws']:6.0f}  ({r['n']} s)")


if __name__ == "__main__":
    main()
