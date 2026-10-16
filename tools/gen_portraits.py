#!/usr/bin/env python3
"""Generates placeholder portrait SVGs for every unit in data/heroes.json.

Placeholders are deliberately abstract (element colour, kind shape, rarity pips;
initials are drawn by the UI because Godot's SVG importer does not render text)
so nothing here resembles any existing game's art. Replace with commissioned
art per docs/ART_SPEC.md; keep the same file names.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS = {
    "flame": ("#f06a3a", "#7a1f0a"),
    "frost": ("#6fc3f0", "#123b5c"),
    "verdant": ("#6fbf5a", "#1d4a1c"),
    "radiant": ("#f2d35a", "#7a5a0e"),
    "umbral": ("#9a6fe0", "#2b1452"),
}
KIND_SHAPE = {"hero": "circle", "enemy": "diamond", "boss": "hex"}

def initials(name):
    parts = [p for p in name.replace("The ", "").split() if p]
    return "".join(p[0] for p in parts[:2]).upper()

def shape(kind, size):
    c = size / 2
    r = size * 0.42
    if kind == "enemy":
        return f'<polygon points="{c},{c-r} {c+r},{c} {c},{c+r} {c-r},{c}" fill="url(#g)" stroke="#111" stroke-width="4"/>'
    if kind == "boss":
        pts = []
        import math
        for i in range(6):
            a = math.pi / 3 * i - math.pi / 6
            pts.append(f"{c + r*math.cos(a):.1f},{c + r*math.sin(a):.1f}")
        return f'<polygon points="{" ".join(pts)}" fill="url(#g)" stroke="#111" stroke-width="4"/>'
    return f'<circle cx="{c}" cy="{c}" r="{r}" fill="url(#g)" stroke="#111" stroke-width="4"/>'

def svg(unit, size=256):
    light, dark = COLORS[unit["element"]]
    kind = unit.get("kind", "hero")
    stars = "".join(
        f'<polygon transform="translate({size/2 - 12*(unit["rarity"]-1) + i*24 - 10},{size-40}) scale(1)" points="10,0 13,7 20,7 14,11 16,18 10,14 4,18 6,11 0,7 7,7" fill="#ffd34a" stroke="#4a3300" stroke-width="1"/>'
        for i in range(unit["rarity"]))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
<defs><radialGradient id="g" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></radialGradient></defs>
<rect width="{size}" height="{size}" rx="24" fill="#1b1f3a"/>
{shape(kind, size)}
{stars}
</svg>
'''

def main():
    units = json.load(open(os.path.join(ROOT, "data", "heroes.json")))
    out = os.path.join(ROOT, "assets", "portraits")
    os.makedirs(out, exist_ok=True)
    for u in units:
        with open(os.path.join(out, f"{u['id']}.svg"), "w") as f:
            f.write(svg(u))
    print(f"wrote {len(units)} portraits to {out}")

if __name__ == "__main__":
    main()
