class_name GearGenerator
extends RefCounted
## Rolls new gear and enhances existing gear. Deterministic given an RNG.

## Number of starting substats by rarity.
const START_SUBS := {2: 1, 3: 2, 4: 3, 5: 4}


static func roll(rng: RandomNumberGenerator, slot: Gear.Slot, rarity: int, set_id: String, tier: int = 1) -> Gear:
	var g := Gear.new()
	g.slot = slot
	g.rarity = clampi(rarity, 2, 5)
	g.set_id = set_id
	g.tier = tier
	var mains: Array = Gear.MAIN_STAT_OPTIONS[slot]
	g.main_stat = mains[rng.randi_range(0, mains.size() - 1)]
	var pool: Array = Gear.SUBSTAT_POOL.duplicate()
	pool.erase(g.main_stat)
	var n: int = START_SUBS[g.rarity]
	for _i in range(n):
		var idx := rng.randi_range(0, pool.size() - 1)
		var stat: String = pool[idx]
		pool.remove_at(idx)
		g.substats[stat] = _roll_sub(rng, stat, tier)
	return g


static func _roll_sub(rng: RandomNumberGenerator, stat: String, tier: int) -> float:
	var r: Array = Gear.SUB_ROLL[stat]
	var v := rng.randf_range(r[0], r[1]) * (1.0 + 0.1 * (tier - 1))
	return snappedf(v, 0.001) if stat in ["atk_pct", "def_pct", "hp_pct", "crit_rate", "crit_dmg", "eff", "res"] else roundf(v)


## Enhances by one level. Every third level (3, 6, 9, 12, 15) either adds a new
## substat (if fewer than 4) or improves an existing one.
static func enhance(rng: RandomNumberGenerator, g: Gear) -> bool:
	if g.level >= Gear.MAX_ENHANCE:
		return false
	g.level += 1
	if g.level % 3 == 0:
		if g.substats.size() < 4:
			var pool: Array = Gear.SUBSTAT_POOL.duplicate()
			pool.erase(g.main_stat)
			for k in g.substats.keys():
				pool.erase(k)
			var stat: String = pool[rng.randi_range(0, pool.size() - 1)]
			g.substats[stat] = _roll_sub(rng, stat, g.tier)
		else:
			var keys := g.substats.keys()
			var stat: String = keys[rng.randi_range(0, keys.size() - 1)]
			g.substats[stat] += _roll_sub(rng, stat, g.tier)
	return true


## Converts a hero's base stats plus a set of Gear into a flat stat bonus
## Dictionary (Stats.KEYS) that can be added to the level-scaled base stats.
static func total_bonus(base: Dictionary, equipped: Array) -> Dictionary:
	var flat := Stats.empty()
	var pct := {"atk_pct": 0.0, "def_pct": 0.0, "hp_pct": 0.0, "spd_pct": 0.0}
	var add := func(stat: String, v: float) -> void:
		if pct.has(stat):
			pct[stat] += v
		else:
			flat[stat] += v
	for g in equipped:
		add.call(g.main_stat, g.main_value())
		for k in g.substats.keys():
			add.call(k, float(g.substats[k]))
	var sets := GearSets.bonuses(equipped)
	for k in sets["mods"].keys():
		add.call(k, float(sets["mods"][k]))
	flat["atk"] += base["atk"] * pct["atk_pct"]
	flat["def"] += base["def"] * pct["def_pct"]
	flat["hp"] += base["hp"] * pct["hp_pct"]
	flat["spd"] += base["spd"] * pct["spd_pct"]
	for k in ["atk", "def", "hp", "spd"]:
		flat[k] = roundf(flat[k])
	return flat
