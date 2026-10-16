class_name GearEconomy
extends RefCounted
## Costs and transformations for gear: enhance, reforge, sell, craft, score.
## All operations go through a PlayerProfile so currencies are enforced.

const ENHANCE_BASE_GOLD := {2: 300, 3: 500, 4: 800, 5: 1200}
const REFORGE_COST := {"gold": 50000, "reforge_stone": 1}
const REFORGE_SUBSTAT_MULT := 1.15
const CRAFT_COST_GOLD := 15000
const CRAFT_MATERIAL_COUNT := 8
const CRAFT_ALLOY_COUNT := 3
const CRAFT_FIVE_STAR_CHANCE := 0.3

## Which boss material unlocks which sets.
const CRAFTABLE_SETS := {
	"ash_scale": ["might", "siphon", "fury"],
	"rime_shard": ["swift", "keen", "ward"],
	"hollow_bone": ["ruin", "precision", "twin", "vigor", "bulwark"],
}
## Later bosses (Milestone 7) unlock: pierce, wrath, aegis, bastion, reckless.

## Substat weights for the gear score (percent stats are scaled to be comparable).
const SCORE_WEIGHTS := {
	"atk_pct": 100.0, "def_pct": 100.0, "hp_pct": 100.0, "eff": 100.0, "res": 100.0,
	"crit_rate": 160.0, "crit_dmg": 115.0, "spd": 2.0,
	"atk": 0.22, "def": 0.33, "hp": 0.045,
}

static var last_error: String = ""


static func enhance_cost(g: Gear) -> int:
	if g.level >= Gear.MAX_ENHANCE:
		return 0
	var base := int(ENHANCE_BASE_GOLD.get(g.rarity, 500))
	return int(roundf(base * pow(float(g.level + 1), 1.3))) * g.tier


static func enhance(profile: PlayerProfile, gear_uid: String, rng: RandomNumberGenerator) -> bool:
	last_error = ""
	var g := profile.get_gear(gear_uid)
	if g == null:
		last_error = "no such gear"
		return false
	if g.level >= Gear.MAX_ENHANCE:
		last_error = "already +15"
		return false
	if not profile.spend({"gold": enhance_cost(g)}):
		last_error = "not enough gold"
		return false
	return GearGenerator.enhance(rng, g)


static func can_reforge(g: Gear) -> bool:
	return g.level >= Gear.MAX_ENHANCE and g.tier == 1


## Reforge: a +15 tier-1 item becomes tier 2 (main stat ×1.1, substats ×1.15).
static func reforge(profile: PlayerProfile, gear_uid: String) -> bool:
	last_error = ""
	var g := profile.get_gear(gear_uid)
	if g == null:
		last_error = "no such gear"
		return false
	if not can_reforge(g):
		last_error = "reforge requires +15 and tier 1"
		return false
	if not profile.spend(REFORGE_COST):
		last_error = "not enough gold or reforge stones"
		return false
	g.tier = 2
	for k in g.substats.keys():
		var v := float(g.substats[k]) * REFORGE_SUBSTAT_MULT
		g.substats[k] = snappedf(v, 0.001) if k in ["atk_pct", "def_pct", "hp_pct", "crit_rate", "crit_dmg", "eff", "res"] else roundf(v)
	return true


static func sell_value(g: Gear) -> int:
	return 200 * g.rarity * g.tier + 150 * g.level


## Sells (converts) gear to gold. Unequips it first.
static func sell(profile: PlayerProfile, gear_uid: String) -> int:
	last_error = ""
	var g := profile.get_gear(gear_uid)
	if g == null:
		last_error = "no such gear"
		return 0
	var owner := profile.gear_owner(gear_uid)
	if owner != "":
		profile.unequip(owner, int(g.slot))
	var value := sell_value(g)
	profile.gear.erase(gear_uid)
	profile.grant({"gold": value})
	return value


static func material_for_set(set_id: String) -> String:
	for mat in CRAFTABLE_SETS.keys():
		if set_id in CRAFTABLE_SETS[mat]:
			return mat
	return ""


static func craft_cost(set_id: String) -> Dictionary:
	var mat := material_for_set(set_id)
	if mat == "":
		return {}
	return {"gold": CRAFT_COST_GOLD, mat: CRAFT_MATERIAL_COUNT, "crafting_alloy": CRAFT_ALLOY_COUNT}


## Crafts a 4★ (70%) or 5★ (30%) item of the chosen slot and set.
static func craft(profile: PlayerProfile, slot: Gear.Slot, set_id: String, rng: RandomNumberGenerator) -> Gear:
	last_error = ""
	var cost := craft_cost(set_id)
	if cost.is_empty():
		last_error = "set %s is not craftable" % set_id
		return null
	if not profile.spend(cost):
		last_error = "missing materials"
		return null
	var rarity := 5 if rng.randf() < CRAFT_FIVE_STAR_CHANCE else 4
	return profile.add_gear(GearGenerator.roll(rng, slot, rarity, set_id))


## A single number for sorting/comparing gear. Main stat is excluded so items
## in different slots compare on substat quality.
static func score(g: Gear) -> float:
	var total := 0.0
	for k in g.substats.keys():
		total += float(g.substats[k]) * float(SCORE_WEIGHTS.get(k, 0.0))
	return snappedf(total, 0.1)
