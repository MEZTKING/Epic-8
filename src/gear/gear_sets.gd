class_name GearSets
extends RefCounted
## Set bonuses. `pieces` is how many items are needed per bonus instance.
## Bonuses stack: two complete 2-piece sets grant the bonus twice.

const SETS := {
	"swift": {"name": "Swift", "pieces": 4, "mods": {"spd_pct": 0.25}},
	"might": {"name": "Might", "pieces": 4, "mods": {"atk_pct": 0.35}},
	"vigor": {"name": "Vigor", "pieces": 2, "mods": {"hp_pct": 0.15}},
	"bulwark": {"name": "Bulwark", "pieces": 2, "mods": {"def_pct": 0.15}},
	"precision": {"name": "Precision", "pieces": 2, "mods": {"crit_rate": 0.12}},
	"ruin": {"name": "Ruin", "pieces": 4, "mods": {"crit_dmg": 0.40}},
	"keen": {"name": "Keen", "pieces": 2, "mods": {"eff": 0.20}},
	"ward": {"name": "Ward", "pieces": 2, "mods": {"res": 0.20}},
	"siphon": {"name": "Siphon", "pieces": 4, "mods": {}, "flags": ["lifesteal_20"]},
	"fury": {"name": "Fury", "pieces": 4, "mods": {}, "flags": ["counter_20"]},
}


## Returns the combined set-bonus modifiers for a list of equipped Gear.
static func bonuses(equipped: Array) -> Dictionary:
	var counts := {}
	for g in equipped:
		counts[g.set_id] = int(counts.get(g.set_id, 0)) + 1
	var mods := {}
	var flags: Array[String] = []
	for set_id in counts.keys():
		if not SETS.has(set_id):
			continue
		var def_: Dictionary = SETS[set_id]
		var times: int = int(counts[set_id]) / int(def_["pieces"])
		for _i in range(times):
			for k in def_["mods"].keys():
				mods[k] = float(mods.get(k, 0.0)) + float(def_["mods"][k])
			for f in def_.get("flags", []):
				flags.append(f)
	return {"mods": mods, "flags": flags}
