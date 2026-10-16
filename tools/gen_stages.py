#!/usr/bin/env python3
"""Generates data/stages.json: adventure chapters, boss hunts, tower floors and
daily dungeons. Deterministic; re-run after changing the tables below."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHAPTERS = [
    ("Mire of Thornwick", "verdant", ["grunt", "marsh_archer", "thorn_spider", "bog_shaman"], "wyrm_of_ash"),
    ("Cinder Steppe", "flame", ["ember_imp", "ember_brute", "cinder_bat", "grunt"], "wyrm_of_ash"),
    ("Hoarfrost Pass", "frost", ["frost_wisp", "frost_golem", "ice_lurker", "marsh_archer"], "glacial_matriarch"),
    ("Barrowlands", "umbral", ["tomb_wraith", "shadow_cutpurse", "gloom_hound", "thorn_spider"], "hollow_king"),
    ("Lantern Reach", "radiant", ["lantern_acolyte", "gilded_sentinel", "bog_shaman", "ember_imp"], "glacial_matriarch"),
    ("Ashen Delta", "flame", ["ember_brute", "cinder_bat", "gloom_hound", "ice_lurker"], "wyrm_of_ash"),
    ("Glass Tundra", "frost", ["frost_golem", "ice_lurker", "gilded_sentinel", "tomb_wraith"], "glacial_matriarch"),
    ("Duskmantle Vale", "umbral", ["shadow_cutpurse", "gloom_hound", "tomb_wraith", "lantern_acolyte"], "hollow_king"),
    ("The Covenant Road", "radiant", ["gilded_sentinel", "lantern_acolyte", "ember_brute", "frost_golem"], "wyrm_of_ash"),
    ("Hollow Throne", "umbral", ["tomb_wraith", "shadow_cutpurse", "gilded_sentinel", "ice_lurker"], "hollow_king"),
]

def adventure():
    out = []
    for c, (name, element, pool, boss) in enumerate(CHAPTERS, start=1):
        for i in range(1, 11):
            level = min(60, 3 + (c - 1) * 6 + i // 2)
            is_boss = i == 10
            n = 2 if (c == 1 and i <= 3) else (3 if i < 7 else 4)
            enemies = [pool[(i + k) % len(pool)] for k in range(n)]
            if is_boss:
                enemies = [boss] + [pool[(i + k) % len(pool)] for k in range(2)]
            stage = {
                "id": f"{c}-{i}", "type": "adventure", "chapter": c, "index": i,
                "name": f"{name} {i}" if not is_boss else f"{name}: Warden",
                "element": element, "energy": 5 if c < 5 else 7, "level": level,
                "enemies": enemies,
                "rewards": {"gold": 100 + level * 30, "xp": 80 + level * 25,
                            "materials": {f"{element}_shard": 2 if is_boss else 1}},
                "first_clear": {"crystals": 100 if is_boss else 30},
                "turn_limit_for_star": 36 if is_boss else 24,
                "requires": "" if (c == 1 and i == 1) else (f"{c}-{i-1}" if i > 1 else f"{c-1}-10"),
            }
            out.append(stage)
    return out

HUNTS = [
    ("wyrm_of_ash", "Ash Wyrm Hunt", "flame", ["ember_imp", "cinder_bat"], "ash_scale"),
    ("glacial_matriarch", "Glacial Hunt", "frost", ["frost_wisp", "ice_lurker"], "rime_shard"),
    ("hollow_king", "Hollow Hunt", "umbral", ["tomb_wraith", "gloom_hound"], "hollow_bone"),
]

def hunts():
    out = []
    for boss, name, element, adds, material in HUNTS:
        key = boss.split("_")[0]
        for tier in range(1, 14):
            level = min(60, 20 + tier * 3)
            enemies = [boss] + (adds if tier >= 4 else adds[:1])
            out.append({
                "id": f"hunt_{key}_{tier}", "type": "hunt", "boss": boss, "tier": tier,
                "name": f"{name} {tier}", "element": element, "energy": 8 + tier // 3, "level": level,
                "enemies": enemies,
                "rewards": {"gold": 300 + tier * 120, "xp": 150 + tier * 40,
                            "materials": {material: 1 + tier // 2, "crafting_alloy": 1 if tier >= 7 else 0}},
                "first_clear": {"crystals": 50},
                "turn_limit_for_star": 30,
                "gear_drop": {"chance": min(0.25 + tier * 0.05, 0.9),
                              "rarity_weights": {"3": max(60 - tier * 5, 5), "4": 35, "5": min(5 + tier * 3, 45)},
                              "tier": 2 if tier >= 12 else 1},
                "requires": "" if tier == 1 else f"hunt_{key}_{tier-1}",
            })
    return out

def tower():
    out = []
    pools = [c[2] for c in CHAPTERS]
    bosses = ["wyrm_of_ash", "glacial_matriarch", "hollow_king"]
    for f in range(1, 51):
        level = min(60, 10 + f)
        pool = pools[(f - 1) % len(pools)]
        enemies = [pool[(f + k) % len(pool)] for k in range(4)]
        if f % 10 == 0:
            enemies = [bosses[(f // 10 - 1) % 3]] + enemies[:2]
        out.append({
            "id": f"tower_{f}", "type": "tower", "floor": f, "name": f"Spire floor {f}",
            "element": "", "energy": 0, "level": level, "enemies": enemies,
            "rewards": {"gold": 500 + f * 100, "xp": 0, "materials": {}},
            "first_clear": {"crystals": 150 if f % 10 == 0 else 20, "summon_ticket": 1 if f % 10 == 0 else 0},
            "turn_limit_for_star": 30,
            "requires": "" if f == 1 else f"tower_{f-1}",
            "once": True,
        })
    return out

DAILY = [("flame", [1, 4], ["ember_imp", "ember_brute", "cinder_bat", "ember_imp"]),
         ("frost", [2, 5], ["frost_wisp", "frost_golem", "ice_lurker", "frost_wisp"]),
         ("verdant", [3, 6], ["grunt", "marsh_archer", "thorn_spider", "bog_shaman"]),
         ("radiant", [1, 3, 5], ["lantern_acolyte", "gilded_sentinel", "lantern_acolyte", "gilded_sentinel"]),
         ("umbral", [2, 4, 6], ["tomb_wraith", "shadow_cutpurse", "gloom_hound", "tomb_wraith"])]

def daily():
    out = []
    for element, days, enemies in DAILY:
        for diff, level in ((1, 20), (2, 40), (3, 60)):
            out.append({
                "id": f"daily_{element}_{diff}", "type": "daily", "element": element, "difficulty": diff,
                "name": f"{element.capitalize()} Sanctum {diff}", "weekdays": days + [0],
                "energy": 6 + diff * 2, "level": level, "enemies": enemies,
                "rewards": {"gold": 200 * diff, "xp": 100 * diff,
                            "materials": {f"{element}_shard": 4 * diff, f"{element}_core": diff - 1}},
                "first_clear": {"crystals": 20}, "turn_limit_for_star": 24,
                "requires": "" if diff == 1 else f"daily_{element}_{diff-1}",
            })
    return out

def main():
    stages = adventure() + hunts() + tower() + daily()
    for s in stages:
        s["rewards"]["materials"] = {k: v for k, v in s["rewards"]["materials"].items() if v > 0}
        if "first_clear" in s:
            s["first_clear"] = {k: v for k, v in s["first_clear"].items() if v > 0}
    path = os.path.join(ROOT, "data", "stages.json")
    json.dump(stages, open(path, "w"), indent=1)
    print(f"wrote {len(stages)} stages to {path}")

if __name__ == "__main__":
    main()
