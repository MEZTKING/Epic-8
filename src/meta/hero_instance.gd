class_name HeroInstance
extends RefCounted
## One owned copy of a hero: level, stars, awakening, skill levels, gear.

var uid: String = ""
var hero_id: String
var stars: int = 3
var level: int = 1
var xp: int = 0
var awakening: int = 0
var bond_level: int = 0
var skill_levels: Array[int] = []
var equipped: Dictionary = {}   # Gear.Slot (int) -> gear uid
var locked: bool = false        # cannot be used as fodder


static func create(p_hero_id: String) -> HeroInstance:
	var h := HeroInstance.new()
	var data := HeroDB.get_hero(p_hero_id)
	if data == null:
		push_error("Unknown hero id %s" % p_hero_id)
		return null
	h.hero_id = p_hero_id
	h.stars = clampi(data.rarity, Progression.MIN_STARS, Progression.MAX_STARS)
	for _i in data.skills.size():
		h.skill_levels.append(0)
	return h


func data() -> HeroData:
	return HeroDB.get_hero(hero_id)


func level_cap() -> int:
	return Progression.level_cap(stars)


func is_max_level() -> bool:
	return level >= level_cap()


func xp_to_next() -> int:
	return 0 if is_max_level() else Progression.xp_for_level(level)


## Adds XP, levelling up as far as the cap allows. Returns levels gained.
func add_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(amount, 0)
	while not is_max_level() and xp >= Progression.xp_for_level(level):
		xp -= Progression.xp_for_level(level)
		level += 1
		gained += 1
	if is_max_level():
		xp = 0
	return gained


func can_promote() -> bool:
	return stars < Progression.MAX_STARS and is_max_level()


## Fodder requirement: `stars` units of the same star count.
func fodder_needed() -> int:
	return stars


func promote() -> void:
	stars += 1
	level = 1
	xp = 0


func can_awaken() -> bool:
	return awakening < Progression.MAX_AWAKENING


func awakening_cost() -> Dictionary:
	return Progression.awakening_cost(awakening + 1, data().element)


func awaken() -> void:
	if can_awaken():
		awakening += 1


func add_bond() -> bool:
	if bond_level >= Progression.MAX_BOND:
		return false
	bond_level += 1
	return true


func set_skill_level(index: int, lvl: int) -> void:
	skill_levels[index] = clampi(lvl, 0, data().skills[index].max_level())


## Stats with level, awakening and the given gear applied (no bonds, no buffs).
func compute_stats(gear_items: Array) -> Dictionary:
	var base := Stats.at_level(data().max_stats, level)
	var bonus := Progression.awakening_bonus(awakening)
	for k in Stats.KEYS:
		if not bonus.has(k):
			continue
		if k in Stats.PERCENT_KEYS:
			base[k] = float(base[k]) + float(bonus[k])
		else:
			base[k] = roundf(float(base[k]) * (1.0 + float(bonus[k])))
	if gear_items.is_empty():
		return base
	return Stats.add(base, GearGenerator.total_bonus(base, gear_items))


func to_dict() -> Dictionary:
	return {
		"uid": uid, "hero_id": hero_id, "stars": stars, "level": level, "xp": xp,
		"awakening": awakening, "bond_level": bond_level, "skill_levels": Array(skill_levels),
		"equipped": equipped.duplicate(), "locked": locked,
	}


static func from_dict(d: Dictionary) -> HeroInstance:
	var h := HeroInstance.create(str(d["hero_id"]))
	if h == null:
		return null
	h.uid = str(d.get("uid", ""))
	h.stars = int(d.get("stars", h.stars))
	h.level = int(d.get("level", 1))
	h.xp = int(d.get("xp", 0))
	h.awakening = int(d.get("awakening", 0))
	h.bond_level = int(d.get("bond_level", 0))
	var levels: Array = d.get("skill_levels", [])
	for i in mini(levels.size(), h.skill_levels.size()):
		h.skill_levels[i] = int(levels[i])
	for k in d.get("equipped", {}).keys():
		h.equipped[int(k)] = str(d["equipped"][k])
	h.locked = bool(d.get("locked", false))
	return h
