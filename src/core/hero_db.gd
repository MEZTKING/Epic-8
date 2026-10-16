class_name HeroDB
extends RefCounted
## Loads and caches all hero and skill definitions from data/*.json.
## Static so it works both in-game and under the headless test runner.

static var _heroes: Dictionary = {}
static var _skills: Dictionary = {}
static var _loaded := false


static func load_all(force := false) -> void:
	if _loaded and not force:
		return
	_skills.clear()
	_heroes.clear()
	for d in _read_json("res://data/skills.json"):
		var s := SkillData.from_dict(d)
		_skills[s.id] = s
	for d in _read_json("res://data/heroes.json"):
		var h := HeroData.from_dict(d, _skills)
		_heroes[h.id] = h
	_loaded = true


static func _read_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % path)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		return parsed
	push_error("%s must contain a JSON array" % path)
	return []


static func get_hero(id: String) -> HeroData:
	load_all()
	return _heroes.get(id)


static func get_skill(id: String) -> SkillData:
	load_all()
	return _skills.get(id)


static func all_heroes() -> Array[HeroData]:
	load_all()
	var out: Array[HeroData] = []
	for h in _heroes.values():
		out.append(h)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


static func heroes_by_rarity(rarity: int) -> Array[String]:
	load_all()
	var out: Array[String] = []
	for h in all_heroes():
		if h.rarity == rarity:
			out.append(h.id)
	return out
