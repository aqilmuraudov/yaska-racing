"""Phone import settings for a baked kart texture set (run after the first
Godot import): VRAM compression + mipmaps, normal map mode, ORM without
alpha-border fixing (its alpha is the garage paint mask).
  python tools/blender/fix_imports.py assets/models/<racer>
"""
import re
import sys

d = sys.argv[1].rstrip("/") + "/"


def setp(f, kv):
    p = d + f + ".import"
    s = open(p, encoding="utf-8").read()
    for k, v in kv.items():
        s, n = re.subn(r"^%s=.*$" % re.escape(k), "%s=%s" % (k, v), s, flags=re.M)
        assert n == 1, (f, k)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


c = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}
setp("albedo.png", c)
setp("normal.png", dict(c, **{"compress/normal_map": "1"}))
setp("orm.png", dict(c, **{"process/fix_alpha_border": "false", "compress/channel_pack": "1"}))
print("ok", d)
