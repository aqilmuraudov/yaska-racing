"""Validates localization/strings.csv: column count, duplicate keys, empty cells."""
import csv, sys
path = sys.argv[1] if len(sys.argv) > 1 else "localization/strings.csv"
with open(path, encoding="utf-8", newline="") as f:
    rows = list(csv.reader(f))
header = rows[0]
seen = set()
bad = 0
for i, r in enumerate(rows[1:], start=2):
    if len(r) != len(header):
        print(f"line {i}: {len(r)} columns: {r[:1]}"); bad += 1
    elif r[0] in seen:
        print(f"line {i}: duplicate key {r[0]}"); bad += 1
    else:
        seen.add(r[0])
        for c, v in zip(header[1:], r[1:]):
            if not v.strip() and r[0] not in ("HUD_POS_SUFFIX",):
                print(f"line {i}: empty {c} for {r[0]}"); bad += 1
print(f"{len(rows)-1} keys, {bad} problems")
sys.exit(1 if bad else 0)
