class_name DemoTeams
extends RefCounted
## Builds sample geared teams for the sandbox and for opening the battle
## scene directly from the editor.


static func build(ids: Array, team: int, level: int, gear_rarity: int, rng: RandomNumberGenerator) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var sets := ["swift", "might", "fury", "siphon", "precision", "twin"]
	for i in ids.size():
		var hero := HeroDB.get_hero(ids[i])
		var base := Stats.at_level(hero.max_stats, level)
		var items: Array = []
		var set_id: String = sets[(i + team) % sets.size()]
		for s in range(6):
			var g := GearGenerator.roll(rng, s as Gear.Slot, gear_rarity, set_id)
			for _k in range(9):
				GearGenerator.enhance(rng, g)
			items.append(g)
		out.append(BattleUnit.new(hero, team, i, level, GearGenerator.total_bonus(base, items), GearSets.bonuses(items)["flags"]))
	return out


static func default_battle(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"player": build(["kaelen", "mira", "ilsabet", "seraphi"], 0, 60, 4, rng),
		"enemy": build(["vexmoor", "bramble", "corvina", "grunt"], 1, 55, 3, rng),
		"seed": seed_value, "auto": false, "return_to": "res://scenes/main.tscn", "context": {},
	}
