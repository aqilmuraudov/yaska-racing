"""Strict test run (0.12.0): fails a test method that hit a SCRIPT ERROR.

Godot 4.4's GDScript runner cannot catch script errors: a test coroutine that
crashes simply stops, and tests/run_tests.gd still prints [PASS] for it (the
checks after the crash never ran). This wrapper runs the normal suite, reads
its output and charges every "SCRIPT ERROR" to the test whose result line
follows it (errors are printed while that method runs, before its line).

Usage:
  python tools/run_tests.py [--godot PATH] [-- --only=fragment]
  (GODOT env var also works; default "godot".)
Exit code 0 only when the suite passes AND no script error occurred.
"""
import os
import re
import subprocess
import sys

RESULT = re.compile(r"^\[(PASS|FAIL)\] (\S+)")
SUMMARY = re.compile(r"^(\d+) test methods, (\d+) checks, (\d+) failures")


def attribute(lines):
    """Returns (errors_by_test, stray_errors, summary_line, runner_ok)."""
    pending = []  # script errors since the last result line
    by_test = {}
    summary = ""
    for i, line in enumerate(lines):
        if line.startswith("SCRIPT ERROR"):
            where = lines[i + 1].strip() if i + 1 < len(lines) else ""
            pending.append(line.strip() + (" " + where if where.startswith("at:") else ""))
            continue
        m = RESULT.match(line)
        if m:
            if pending:
                by_test[m.group(2)] = pending
            pending = []
            continue
        if SUMMARY.match(line):
            summary = line.strip()
    return by_test, pending, summary


def main() -> int:
    args = sys.argv[1:]
    godot = os.environ.get("GODOT", "godot")
    if args[:1] == ["--godot"]:
        godot, args = args[1], args[2:]
    extra = args[1:] if args[:1] == ["--"] else args
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    cmd = [godot, "--headless", "--path", root, "--audio-driver", "Dummy", "-s", "tests/run_tests.gd"]
    if extra:
        cmd += ["--"] + extra
    # One stream so script errors (stderr) stay in order with [PASS] (stdout).
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                          encoding="utf-8", errors="replace")
    out = proc.stdout.splitlines()
    rc = proc.returncode
    by_test, stray, summary = attribute(out)
    for line in out:
        if line.startswith("[FAIL]") or line.startswith("    ✗"):
            print(line)
    for test, errs in by_test.items():
        print(f"[SCRIPT ERROR] {test}")
        for e in errs[:3]:
            print("    " + e)
        if len(errs) > 3:
            print(f"    ... {len(errs) - 3} more")
    if stray:
        print(f"[SCRIPT ERROR] outside any test: {len(stray)}")
    print(summary or "no summary line (runner crashed?)")
    n_err = sum(len(v) for v in by_test.values()) + len(stray)
    print(f"script errors: {n_err} in {len(by_test)} test methods")
    return 0 if rc == 0 and n_err == 0 and summary else 1


if __name__ == "__main__":
    sys.exit(main())
