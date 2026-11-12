"""Copy the game's saved data (profile, settings, ghosts, logs) from the old
package az.bakuturbo.game to the new one az.yaskaracing.game (0.20.3) over USB.

Both builds are debug APKs, so `adb shell run-as <pkg>` can read and write
their private files (user:// = /data/data/<pkg>/files). Nothing is deleted:
the old app keeps its files; the new app's files with the same name are
overwritten. Close the game on the phone first.

    python tools/migrate_profile.py            # copy
    python tools/migrate_profile.py --dry-run  # list what would be copied
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

OLD = "az.bakuturbo.game"
NEW = "az.yaskaracing.game"
ADB = os.environ.get("ADB") or shutil.which("adb") or "C:/Tools/AndroidSdk/platform-tools/adb.exe"
TMP = "/data/local/tmp/yaska_migrate"


def adb(*args: str, binary: bool = False) -> bytes | str:
    r = subprocess.run([ADB, *args], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError("adb %s: %s" % (" ".join(args), r.stderr.decode(errors="replace").strip()))
    return r.stdout if binary else r.stdout.decode(errors="replace")


def installed(pkg: str) -> bool:
    return ("package:" + pkg) in adb("shell", "pm", "list", "packages", pkg).split()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    devices = [l for l in adb("devices").splitlines()[1:] if l.strip().endswith("device")]
    if len(devices) != 1:
        print("connect exactly one phone with USB debugging (found %d)" % len(devices))
        return 1
    for pkg in (OLD, NEW):
        if not installed(pkg):
            print("%s is not installed" % pkg)
            return 1
    files = [f.strip() for f in adb("shell", "run-as", OLD, "find", "files", "-type", "f").splitlines() if f.strip()]
    if not files:
        print("the old app has no saved files")
        return 1
    print("%d files in %s:" % (len(files), OLD))
    for f in files:
        print("  " + f)
    if a.dry_run:
        return 0
    adb("shell", "am", "force-stop", NEW)
    adb("shell", "mkdir", "-p", TMP)
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(files):
            data = adb("exec-out", "run-as", OLD, "cat", f, binary=True)
            local = os.path.join(tmp, "f%d" % i)
            with open(local, "wb") as h:
                h.write(data)
            remote = "%s/f%d" % (TMP, i)
            adb("push", local, remote)
            adb("shell", "chmod", "644", remote)
            d = os.path.dirname(f)
            adb("shell", "run-as", NEW, "mkdir", "-p", d)
            adb("shell", "run-as", NEW, "cp", remote, f)
            got = adb("exec-out", "run-as", NEW, "cat", f, binary=True)
            if got != data:
                print("MISMATCH " + f)
                return 1
            print("copied %s (%d bytes)" % (f, len(data)))
    adb("shell", "rm", "-rf", TMP)
    print("done: start Yaska Racing (new) - the old app can be uninstalled after a check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
