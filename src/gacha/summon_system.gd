class_name SummonSystem
extends RefCounted
## Banner summons with published rates and a hard pity counter.
## Rates are this project's own tuning. Every number here must be shown to the
## player in-game (store/platform loot-box disclosure rules).

const RATES := {5: 0.0150, 4: 0.0500, 3: 0.9350}
const FEATURED_SHARE := 0.5      # share of 5-star pulls that are the featured hero
const HARD_PITY := 120           # the featured hero is guaranteed on this pull
const COST_PER_PULL := 100       # premium currency

var rng := RandomNumberGenerator.new()
var featured_id: String = ""
var pity_counter: int = 0
var total_pulls: int = 0
var history: Array[Dictionary] = []


func _init(seed_value: int = 0, p_featured: String = "") -> void:
	rng.seed = seed_value
	featured_id = p_featured


func pull() -> Dictionary:
	total_pulls += 1
	pity_counter += 1
	var result := {"rarity": 3, "hero_id": "", "featured": false, "pity": false, "pull_no": total_pulls}
	if featured_id != "" and pity_counter >= HARD_PITY:
		result["rarity"] = 5
		result["hero_id"] = featured_id
		result["featured"] = true
		result["pity"] = true
	else:
		var roll := rng.randf()
		var rarity := 3
		if roll < RATES[5]:
			rarity = 5
		elif roll < RATES[5] + RATES[4]:
			rarity = 4
		result["rarity"] = rarity
		if rarity == 5 and featured_id != "" and rng.randf() < FEATURED_SHARE:
			result["hero_id"] = featured_id
			result["featured"] = true
		else:
			result["hero_id"] = _random_hero(rarity)
	if result["featured"]:
		pity_counter = 0
	history.append(result)
	return result


func pull_many(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _i in range(n):
		out.append(pull())
	return out


func _random_hero(rarity: int) -> String:
	var pool := HeroDB.heroes_by_rarity(rarity)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


## Human-readable rate table for the in-game disclosure panel.
static func rate_table() -> Array[Dictionary]:
	return [
		{"rarity": 5, "rate": RATES[5]},
		{"rarity": 4, "rate": RATES[4]},
		{"rarity": 3, "rate": RATES[3]},
	]
