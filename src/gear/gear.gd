class_name Gear
extends RefCounted
## One equippable item. Six slots, one main stat, up to four substats, a set.

enum Slot { WEAPON, HELM, ARMOR, NECKLACE, RING, BOOTS }

const SLOT_NAMES := ["Weapon", "Helm", "Armor", "Necklace", "Ring", "Boots"]

## Fixed main stats for the first three slots; the rest roll from a list.
const MAIN_STAT_OPTIONS := {
	Slot.WEAPON: ["atk"],
	Slot.HELM: ["hp"],
	Slot.ARMOR: ["def"],
	Slot.NECKLACE: ["atk_pct", "def_pct", "hp_pct", "crit_rate", "crit_dmg"],
	Slot.RING: ["atk_pct", "def_pct", "hp_pct", "eff", "res"],
	Slot.BOOTS: ["atk_pct", "def_pct", "hp_pct", "spd"],
}

const SUBSTAT_POOL := ["atk", "atk_pct", "def", "def_pct", "hp", "hp_pct", "spd", "crit_rate", "crit_dmg", "eff", "res"]

## Value of a main stat at +0 and at +15 (linear in between).
const MAIN_RANGE := {
	"atk": [100.0, 525.0], "def": [60.0, 310.0], "hp": [540.0, 2835.0],
	"atk_pct": [0.12, 0.65], "def_pct": [0.12, 0.65], "hp_pct": [0.12, 0.65],
	"spd": [8.0, 45.0], "crit_rate": [0.10, 0.55], "crit_dmg": [0.14, 0.70],
	"eff": [0.12, 0.65], "res": [0.12, 0.65],
}

## Substat roll ranges per roll (min, max).
const SUB_ROLL := {
	"atk": [20.0, 45.0], "def": [15.0, 35.0], "hp": [100.0, 230.0],
	"atk_pct": [0.04, 0.08], "def_pct": [0.04, 0.08], "hp_pct": [0.04, 0.08],
	"spd": [2.0, 5.0], "crit_rate": [0.03, 0.05], "crit_dmg": [0.04, 0.07],
	"eff": [0.04, 0.08], "res": [0.04, 0.08],
}

const MAX_ENHANCE := 15

var slot: Slot
var rarity: int = 3           # 2..5 stars; determines starting substat count
var set_id: String = "swift"
var level: int = 0            # enhancement +0..+15
var main_stat: String
var substats: Dictionary = {} # stat -> value
var tier: int = 1             # item level tier, scales rolls (1 = base)


func main_value() -> float:
	var r: Array = MAIN_RANGE[main_stat]
	return lerpf(r[0], r[1], float(level) / MAX_ENHANCE) * (1.0 + 0.1 * (tier - 1))


func slot_name() -> String:
	return SLOT_NAMES[slot]


func to_dict() -> Dictionary:
	return {
		"slot": slot, "rarity": rarity, "set_id": set_id, "level": level,
		"main_stat": main_stat, "substats": substats.duplicate(), "tier": tier,
	}


static func from_dict(d: Dictionary) -> Gear:
	var g := Gear.new()
	g.slot = int(d["slot"]) as Slot
	g.rarity = int(d.get("rarity", 3))
	g.set_id = str(d.get("set_id", "swift"))
	g.level = int(d.get("level", 0))
	g.main_stat = str(d["main_stat"])
	g.substats = d.get("substats", {}).duplicate()
	g.tier = int(d.get("tier", 1))
	return g
