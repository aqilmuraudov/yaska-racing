"""Writes the original illustrated SVG icons used by the menus and HUD
(assets/icons/ui/*.svg) and the two language flags.

Style: chunky shapes, dark navy outline, one or two fills plus a white gloss.
Run from the project root:  python tools/gen_icons.py
"""
import math
import os

OUT = "assets/icons/ui"
INK = "#0c2559"
SW = 7  # outline width


def svg(body, w=128, h=128):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')


def o(fill):
    return f'fill="{fill}" stroke="{INK}" stroke-width="{SW}"'


def gloss(x, y, w, h, r=10):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="#fff" opacity="0.35"/>'


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append(f"{cx + r * math.cos(a):.2f},{cy + r * math.sin(a):.2f}")
    return " ".join(pts)


ICONS = {}

# Tabs ---------------------------------------------------------------------
ICONS["tab_graphics"] = svg(
    f'<rect x="12" y="20" width="104" height="80" rx="16" {o("#2f7de1")}/>'
    '<path d="M18 92 L48 58 L66 76 L82 60 L110 92 Z" fill="#6fcf3c"/>'
    '<circle cx="88" cy="42" r="11" fill="#ffd23f"/>'
    f'<rect x="12" y="20" width="104" height="80" rx="16" fill="none" stroke="{INK}" stroke-width="{SW}"/>'
    + gloss(22, 27, 84, 14, 7) +
    f'<rect x="44" y="102" width="40" height="14" rx="6" {o("#8d98ad")}/>')
ICONS["tab_audio"] = svg(
    f'<path d="M16 50 H40 L68 26 V102 L40 78 H16 Z" {o("#ffc21a")}/>'
    f'<path d="M82 46 Q94 64 82 82" fill="none" stroke="{INK}" stroke-width="10"/>'
    '<path d="M82 46 Q94 64 82 82" fill="none" stroke="#17b9c9" stroke-width="5"/>'
    f'<path d="M96 32 Q118 64 96 96" fill="none" stroke="{INK}" stroke-width="10"/>'
    '<path d="M96 32 Q118 64 96 96" fill="none" stroke="#17b9c9" stroke-width="5"/>'
    + gloss(22, 54, 16, 8, 4))
ICONS["tab_controls"] = svg(
    f'<circle cx="64" cy="64" r="48" {o("#ff5f6d")}/>'
    '<circle cx="64" cy="64" r="30" fill="#ffe6e8"/>'
    f'<circle cx="64" cy="64" r="30" fill="none" stroke="{INK}" stroke-width="5"/>'
    f'<path d="M36 70 H92 M64 70 V94" stroke="{INK}" stroke-width="12"/>'
    '<path d="M36 70 H92 M64 70 V94" stroke="#ff5f6d" stroke-width="6"/>'
    f'<circle cx="64" cy="68" r="10" {o("#ffd23f")}/>'
    '<path d="M30 40 A40 40 0 0 1 64 20" fill="none" stroke="#fff" stroke-width="6" opacity="0.5"/>')
ICONS["tab_language"] = svg(
    f'<circle cx="58" cy="62" r="44" {o("#17b9c9")}/>'
    '<path d="M30 40 Q44 48 40 62 Q36 74 48 82 Q46 94 40 100 M72 22 Q66 34 78 40 Q92 42 96 54 Q86 66 94 80" fill="none" stroke="#6fcf3c" stroke-width="12"/>'
    f'<circle cx="58" cy="62" r="44" fill="none" stroke="{INK}" stroke-width="{SW}"/>'
    f'<path d="M80 74 H118 Q122 74 122 78 V104 Q122 108 118 108 H100 L90 118 V108 H80 Q76 108 76 104 V78 Q76 74 80 74 Z" {o("#ffd23f")}/>'
    f'<circle cx="90" cy="91" r="3.5" fill="{INK}"/><circle cx="99" cy="91" r="3.5" fill="{INK}"/><circle cx="108" cy="91" r="3.5" fill="{INK}"/>')

# Rows ---------------------------------------------------------------------
ICONS["texture"] = svg(
    f'<rect x="16" y="16" width="96" height="96" rx="14" {o("#f0c98a")}/>'
    '<path d="M20 48 H108 M20 80 H108 M48 20 V48 M88 20 V48 M32 48 V80 M72 48 V80 M48 80 V108 M92 80 V108" stroke="#b9874a" stroke-width="6"/>'
    f'<rect x="16" y="16" width="96" height="96" rx="14" fill="none" stroke="{INK}" stroke-width="{SW}"/>'
    + gloss(24, 22, 80, 12, 6))
ICONS["fps"] = svg(
    f'<path d="M14 92 A50 50 0 1 1 114 92 Z" {o("#2f7de1")}/>'
    '<path d="M26 88 A38 38 0 0 1 52 52" fill="none" stroke="#6fcf3c" stroke-width="10"/>'
    '<path d="M54 50 A38 38 0 0 1 88 54" fill="none" stroke="#ffd23f" stroke-width="10"/>'
    '<path d="M90 56 A38 38 0 0 1 102 88" fill="none" stroke="#ff5f6d" stroke-width="10"/>'
    f'<path d="M64 88 L92 48" stroke="{INK}" stroke-width="11"/><path d="M64 88 L92 48" stroke="#fff" stroke-width="5"/>'
    f'<circle cx="64" cy="88" r="10" {o("#ffd23f")}/>')
ICONS["shadows"] = svg(
    '<ellipse cx="74" cy="104" rx="44" ry="12" fill="#0c2559" opacity="0.45"/>'
    f'<rect x="50" y="44" width="40" height="58" rx="10" {o("#ff8a1f")}/>' + gloss(56, 50, 12, 40, 5) +
    f'<circle cx="30" cy="30" r="16" {o("#ffd23f")}/>')
ICONS["master"] = ICONS["tab_audio"]
ICONS["music"] = svg(
    f'<path d="M44 92 V28 L104 16 V80" fill="none" stroke="{INK}" stroke-width="16"/>'
    '<path d="M44 92 V28 L104 16 V80" fill="none" stroke="#8b5cf6" stroke-width="8"/>'
    f'<ellipse cx="32" cy="94" rx="20" ry="15" {o("#8b5cf6")}/>'
    f'<ellipse cx="92" cy="82" rx="20" ry="15" {o("#8b5cf6")}/>'
    '<ellipse cx="26" cy="89" rx="7" ry="4" fill="#fff" opacity="0.5"/><ellipse cx="86" cy="77" rx="7" ry="4" fill="#fff" opacity="0.5"/>')
ICONS["sfx"] = svg(
    f'<polygon points="{star_points(64, 64, 52, 26, 8, -90)}" {o("#ff8a1f")}/>'
    f'<polygon points="{star_points(64, 64, 28, 14, 5)}" fill="#ffd23f" stroke="{INK}" stroke-width="5"/>')
ICONS["control_type"] = svg(
    f'<g transform="rotate(-14 64 64)"><rect x="18" y="38" width="92" height="52" rx="12" {o("#2f7de1")}/>'
    '<rect x="28" y="46" width="72" height="36" rx="5" fill="#bfe6ff"/>' + gloss(30, 48, 68, 8, 4) + '</g>'
    f'<path d="M14 26 Q30 12 46 18" fill="none" stroke="{INK}" stroke-width="11"/>'
    '<path d="M14 26 Q30 12 46 18" fill="none" stroke="#ffd23f" stroke-width="5"/>'
    f'<path d="M114 102 Q98 116 82 110" fill="none" stroke="{INK}" stroke-width="11"/>'
    '<path d="M114 102 Q98 116 82 110" fill="none" stroke="#ffd23f" stroke-width="5"/>')
ICONS["button_size"] = svg(
    f'<circle cx="36" cy="84" r="18" {o("#17b9c9")}/>'
    f'<circle cx="84" cy="56" r="32" {o("#ff5f6d")}/>'
    '<ellipse cx="74" cy="42" rx="12" ry="7" fill="#fff" opacity="0.45"/>'
    '<ellipse cx="31" cy="77" rx="6" ry="4" fill="#fff" opacity="0.45"/>')
ICONS["auto_accel"] = svg(
    f'<path d="M30 24 H78 L98 104 H50 Z" {o("#8d98ad")}/>'
    '<path d="M42 40 H74 M46 58 H80 M50 76 H86" stroke="#5c6680" stroke-width="7"/>'
    f'<circle cx="94" cy="34" r="22" {o("#6fcf3c")}/>'
    f'<text x="94" y="45" font-family="sans-serif" font-weight="900" font-size="30" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="2">A</text>')
ICONS["steering"] = svg(
    f'<circle cx="64" cy="70" r="38" {o("#ff8a1f")}/>'
    '<circle cx="64" cy="70" r="22" fill="#ffe2c4"/>'
    f'<circle cx="64" cy="70" r="22" fill="none" stroke="{INK}" stroke-width="5"/>'
    f'<path d="M42 74 H86" stroke="{INK}" stroke-width="10"/>'
    f'<path d="M10 40 L24 26 M10 40 L24 54 M10 40 H36" stroke="{INK}" stroke-width="10"/>'
    '<path d="M10 40 L24 26 M10 40 L24 54 M10 40 H36" stroke="#ffd23f" stroke-width="4"/>'
    f'<path d="M118 40 L104 26 M118 40 L104 54 M118 40 H92" stroke="{INK}" stroke-width="10"/>'
    '<path d="M118 40 L104 26 M118 40 L104 54 M118 40 H92" stroke="#ffd23f" stroke-width="4"/>')
ICONS["calibrate"] = svg(
    f'<circle cx="64" cy="64" r="44" {o("#ffffff")}/>'
    f'<circle cx="64" cy="64" r="28" {o("#ff5f6d")}/>'
    f'<circle cx="64" cy="64" r="10" {o("#ffffff")}/>'
    f'<path d="M64 6 V26 M64 102 V122 M6 64 H26 M102 64 H122" stroke="{INK}" stroke-width="8"/>')
ICONS["restore"] = svg(
    f'<path d="M100 64 A36 36 0 1 1 82 33" fill="none" stroke="{INK}" stroke-width="20"/>'
    '<path d="M100 64 A36 36 0 1 1 82 33" fill="none" stroke="#ffd23f" stroke-width="10"/>'
    f'<polygon points="70,10 106,24 78,48" {o("#ffd23f")}/>')
ICONS["back"] = svg(
    f'<path d="M84 18 L36 64 L84 110" fill="none" stroke="{INK}" stroke-width="30"/>'
    '<path d="M84 18 L36 64 L84 110" fill="none" stroke="#ffffff" stroke-width="16"/>')
ICONS["gear"] = svg(
    "".join(f'<rect x="56" y="8" width="16" height="26" rx="4" fill="#ffd23f" stroke="{INK}" stroke-width="5" transform="rotate({a} 64 64)"/>' for a in range(0, 360, 45))
    + f'<circle cx="64" cy="64" r="38" {o("#ffd23f")}/><circle cx="64" cy="64" r="14" {o("#2f7de1")}/>'
    + '<path d="M38 50 A30 30 0 0 1 60 32" fill="none" stroke="#fff" stroke-width="6" opacity="0.6"/>')
ICONS["play"] = svg(f'<polygon points="36,18 108,64 36,110" {o("#ffffff")}/>')
ICONS["trophy"] = svg(
    f'<path d="M36 16 H92 V48 A28 28 0 0 1 36 48 Z" {o("#ffd23f")}/>'
    f'<path d="M36 26 H16 Q16 58 40 60 M92 26 H112 Q112 58 88 60" fill="none" stroke="{INK}" stroke-width="7"/>'
    f'<rect x="54" y="74" width="20" height="18" {o("#ffc21a")}/>'
    f'<rect x="36" y="92" width="56" height="20" rx="6" {o("#ff8a1f")}/>' + gloss(44, 22, 14, 34, 6))

# Game modes ------------------------------------------------------------------
ICONS["mode_quick"] = svg(
    f'<path d="M26 14 V118" stroke="{INK}" stroke-width="12"/><path d="M26 14 V118" stroke="#d9dde3" stroke-width="5"/>'
    f'<path d="M30 18 Q60 8 82 20 T118 22 V74 Q96 64 74 74 T30 70 Z" {o("#ffffff")}/>'
    + "".join(f'<rect x="{30 + c * 22}" y="{20 + r * 18 + (4 if c % 2 else 0)}" width="22" height="18" fill="{INK}"/>'
              for r in range(3) for c in range(4) if (r + c) % 2 == 0))
ICONS["mode_time"] = svg(
    f'<rect x="54" y="6" width="20" height="16" rx="4" {o("#ff8a1f")}/>'
    f'<circle cx="64" cy="72" r="46" {o("#17b9c9")}/>'
    f'<circle cx="64" cy="72" r="34" {o("#ffffff")}/>'
    f'<path d="M64 72 L64 46 M64 72 L84 82" stroke="{INK}" stroke-width="8"/>'
    f'<circle cx="64" cy="72" r="6" fill="{INK}"/>' + gloss(36, 38, 18, 10, 5))
ICONS["mode_school"] = svg(
    f'<polygon points="64,14 122,40 64,66 6,40" {o("#ffd23f")}/>'
    f'<path d="M30 52 V82 Q64 104 98 82 V52 L64 66 Z" {o("#8b5cf6")}/>'
    f'<path d="M110 46 V86" stroke="{INK}" stroke-width="7"/><circle cx="110" cy="92" r="9" {o("#ff5f6d")}/>'
    + gloss(46, 26, 30, 8, 4))

# HUD controls ----------------------------------------------------------------
ICONS["hud_brake"] = svg(
    f'<polygon points="44,10 84,10 118,44 118,84 84,118 44,118 10,84 10,44" {o("#ff5f6d")}/>'
    f'<rect x="30" y="54" width="68" height="20" rx="8" {o("#ffffff")}/>' + gloss(36, 20, 56, 12, 6))
ICONS["hud_drift"] = svg(
    f'<path d="M24 92 Q24 30 84 30" fill="none" stroke="{INK}" stroke-width="26"/>'
    '<path d="M24 92 Q24 30 84 30" fill="none" stroke="#ffd23f" stroke-width="12"/>'
    f'<polygon points="80,8 118,30 80,52" {o("#ffd23f")}/>'
    f'<circle cx="34" cy="108" r="12" {o("#ffffff")}/><circle cx="60" cy="112" r="9" {o("#ffffff")}/>'
    f'<circle cx="82" cy="112" r="6" {o("#ffffff")}/>')
ICONS["hud_nitro"] = svg(
    f'<path d="M64 6 Q100 40 92 74 Q88 104 64 120 Q40 104 36 74 Q28 40 64 6 Z" {o("#ff8a1f")}/>'
    f'<path d="M64 44 Q82 64 78 84 Q74 102 64 108 Q54 102 50 84 Q46 64 64 44 Z" fill="#ffd23f"/>'
    '<path d="M64 70 Q72 82 70 92 Q66 100 64 100 Q58 98 58 90 Q58 80 64 70 Z" fill="#ffffff"/>')
ICONS["hud_recover"] = svg(
    f'<path d="M100 64 A36 36 0 1 1 82 33" fill="none" stroke="{INK}" stroke-width="20"/>'
    '<path d="M100 64 A36 36 0 1 1 82 33" fill="none" stroke="#6fcf3c" stroke-width="10"/>'
    f'<polygon points="70,10 106,24 78,48" {o("#6fcf3c")}/>'
    f'<rect x="46" y="58" width="36" height="18" rx="7" {o("#ff5f6d")}/>'
    f'<circle cx="54" cy="80" r="7" fill="{INK}"/><circle cx="76" cy="80" r="7" fill="{INK}"/>')
ICONS["hud_gas"] = svg(
    f'<path d="M30 24 H78 L98 104 H50 Z" {o("#6fcf3c")}/>'
    '<path d="M42 40 H74 M46 58 H80 M50 76 H86" stroke="#3f8f1f" stroke-width="7"/>' + gloss(40, 30, 30, 8, 4))
ICONS["hud_look_back"] = svg(
    f'<ellipse cx="64" cy="64" rx="54" ry="34" {o("#ffffff")}/>'
    f'<circle cx="64" cy="64" r="20" {o("#17b9c9")}/><circle cx="64" cy="64" r="8" fill="{INK}"/>')
ICONS["star"] = svg(
    f'<polygon points="{star_points(64, 68, 56, 24)}" {o("#ffd23f")}/>'
    '<ellipse cx="50" cy="48" rx="10" ry="6" fill="#fff" opacity="0.6"/>')

# New settings rows -------------------------------------------------------------
ICONS["easy_drift"] = svg(
    f'<path d="M24 92 Q24 30 84 30" fill="none" stroke="{INK}" stroke-width="26"/>'
    '<path d="M24 92 Q24 30 84 30" fill="none" stroke="#17b9c9" stroke-width="12"/>'
    f'<polygon points="80,8 118,30 80,52" {o("#17b9c9")}/>'
    f'<polygon points="{star_points(92, 92, 28, 12)}" {o("#ffd23f")}/>')
ICONS["steer_help"] = svg(
    f'<path d="M30 118 L50 10 M98 118 L78 10" stroke="{INK}" stroke-width="10"/>'
    '<path d="M64 108 V92 M64 72 V56 M64 36 V20" stroke="#ffd23f" stroke-width="8"/>'
    f'<path d="M20 70 Q8 64 20 58" fill="none" stroke="{INK}" stroke-width="7"/>'
    f'<circle cx="64" cy="64" r="18" {o("#6fcf3c")}/>'
    f'<path d="M56 64 L62 70 L74 58" fill="none" stroke="#fff" stroke-width="6"/>')
ICONS["vibration"] = svg(
    f'<rect x="40" y="16" width="48" height="96" rx="12" {o("#2f7de1")}/>'
    '<rect x="48" y="28" width="32" height="64" rx="4" fill="#bfe3ff"/>'
    f'<path d="M24 44 L14 54 L24 64 L14 74 L24 84 M104 44 L114 54 L104 64 L114 74 L104 84" fill="none" stroke="{INK}" stroke-width="7"/>')
ICONS["camera_shake"] = svg(
    f'<rect x="14" y="38" width="84" height="60" rx="12" {o("#8b5cf6")}/>'
    f'<polygon points="98,56 120,44 120,92 98,80" {o("#8b5cf6")}/>'
    f'<circle cx="56" cy="68" r="16" {o("#ffffff")}/>'
    f'<path d="M22 22 Q34 14 46 22 Q58 30 70 22" fill="none" stroke="{INK}" stroke-width="6"/>')
ICONS["parents"] = svg(
    f'<circle cx="44" cy="36" r="18" {o("#ffd23f")}/><circle cx="88" cy="46" r="14" {o("#ffd23f")}/>'
    f'<path d="M16 112 Q16 64 44 64 Q72 64 72 112 Z" {o("#2f7de1")}/>'
    f'<path d="M66 112 Q66 70 88 70 Q110 70 110 112 Z" {o("#ff5f6d")}/>')


def flag_az():
    # Azerbaijan: horizontal blue / red / green, white crescent and
    # eight-pointed star centred on the red band (crescent opens to the fly).
    w, h = 192, 96
    band = h / 3
    cx, cy = w / 2 - 6, h / 2
    r1 = band * 0.375 * 1.2  # outer crescent radius
    r2 = r1 * 0.8
    star = star_points(cx + r1 * 0.9, cy, band * 0.24, band * 0.24 * 0.42, 8, -90)
    body = (
        f'<rect width="{w}" height="{band:.2f}" fill="#00b5e2"/>'
        f'<rect y="{band:.2f}" width="{w}" height="{band:.2f}" fill="#ef3340"/>'
        f'<rect y="{2 * band:.2f}" width="{w}" height="{band:.2f}" fill="#509e2f"/>'
        f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r1:.2f}" fill="#fff"/>'
        f'<circle cx="{cx + r1 * 0.25:.2f}" cy="{cy:.2f}" r="{r2:.2f}" fill="#ef3340"/>'
        f'<polygon points="{star}" fill="#fff"/>'
    )
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'


def flag_uk():
    # Union Flag (the usual flag for "English" language choices), 2:1.
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="96" viewBox="0 0 60 30">'
        '<clipPath id="s"><path d="M0,0 v30 h60 v-30 z"/></clipPath>'
        '<clipPath id="t"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z"/></clipPath>'
        '<g clip-path="url(#s)">'
        '<path d="M0,0 v30 h60 v-30 z" fill="#012169"/>'
        '<path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>'
        '<path d="M0,0 L60,30 M60,0 L0,30" clip-path="url(#t)" stroke="#C8102E" stroke-width="4"/>'
        '<path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/>'
        '<path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/>'
        '</g></svg>')


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, text in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    for name, text in (("flag_az", flag_az()), ("flag_en", flag_uk())):
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print(len(ICONS) + 2, "icons written to", OUT)
