"""Parses every GDScript file with Godot --check-only and reports errors.

Usage: python tools/check_scripts.py [godot_binary]
Autoload identifiers are not registered in check-only mode, so errors that
only complain about them are ignored.
"""
import os, re, subprocess, sys, pathlib

GODOT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
    "GODOT", r"C:\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe")
ROOT = pathlib.Path(__file__).resolve().parent.parent
AUTOLOADS = ("Game", "Settings", "SaveManager", "AudioManager")
IGNORE = re.compile(r"Identifier not found: (%s)\b|Failed to compile depended" % "|".join(AUTOLOADS))

# Refresh the global class cache so new class_name scripts resolve.
subprocess.run([GODOT, "--headless", "--import"], cwd=ROOT, capture_output=True, timeout=600)

failed = 0
files = sorted(p for d in ("scripts", "tests", "tools") for p in (ROOT / d).rglob("*.gd"))
for f in files:
    rel = f.relative_to(ROOT).as_posix()
    out = subprocess.run([GODOT, "--headless", "--check-only", "-s", rel], cwd=ROOT,
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    lines = (out.stdout + out.stderr).splitlines()
    errors = []
    for i, line in enumerate(lines):
        if "SCRIPT ERROR" in line and not IGNORE.search(line):
            loc = lines[i + 1].strip() if i + 1 < len(lines) else ""
            errors.append(f"{line.strip()}\n      {loc}")
    if errors:
        failed += 1
        print(f"== {rel}")
        for e in dict.fromkeys(errors):
            print("   " + e)
print("All scripts parse OK" if not failed else f"{failed} file(s) with errors")
sys.exit(1 if failed else 0)
