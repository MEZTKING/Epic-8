class_name PlayerProfile
extends RefCounted
## Everything a player owns. Pure data + rules; no UI, no file IO (see SaveSystem).

const ENERGY_MAX_BASE := 120
const ENERGY_REGEN_SECONDS := 300      # 1 energy per 5 minutes
const STARTING_GOLD := 10000
const STARTING_CRYSTALS := 1500

var name: String = "Player"
var created_at: int = 0
var gold: int = STARTING_GOLD
var crystals: int = STARTING_CRYSTALS     # premium currency
var mileage: int = 0                      # summon exchange currency (Milestone 5)
var energy: int = ENERGY_MAX_BASE
var energy_max: int = ENERGY_MAX_BASE
var energy_updated_at: int = 0
var materials: Dictionary = {}            # id -> count (e.g. "flame_shard")
var heroes: Dictionary = {}               # uid -> HeroInstance
var gear: Dictionary = {}                 # uid -> Gear
var teams: Dictionary = {}                # preset name -> Array[String] hero uids
var flags: Dictionary = {}                # misc progress flags (tutorials, unlocks)
var _next_uid: int = 1


func _init(now_unix: int = 0) -> void:
	created_at = now_unix
	energy_updated_at = now_unix


func new_uid(prefix: String) -> String:
	var id := "%s%06d" % [prefix, _next_uid]
	_next_uid += 1
	return id

# ---------------------------------------------------------------- currencies

func can_afford(cost: Dictionary) -> bool:
	for k in cost.keys():
		var need := int(cost[k])
		match k:
			"gold":
				if gold < need: return false
			"crystals":
				if crystals < need: return false
			"energy":
				if energy < need: return false
			"mileage":
				if mileage < need: return false
			_:
				if int(materials.get(k, 0)) < need: return false
	return true


## Deducts a cost dictionary. Returns false (and changes nothing) if unaffordable.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost.keys():
		var n := int(cost[k])
		match k:
			"gold": gold -= n
			"crystals": crystals -= n
			"energy": energy -= n
			"mileage": mileage -= n
			_: materials[k] = int(materials[k]) - n
	return true


func grant(reward: Dictionary) -> void:
	for k in reward.keys():
		var n := int(reward[k])
		match k:
			"gold": gold += n
			"crystals": crystals += n
			"energy": energy += n
			"mileage": mileage += n
			_: materials[k] = int(materials.get(k, 0)) + n


## Regenerates energy based on elapsed real time. Call before reading energy.
func regen_energy(now_unix: int) -> void:
	if now_unix <= energy_updated_at:
		return
	if energy >= energy_max:
		energy_updated_at = now_unix
		return
	var ticks := (now_unix - energy_updated_at) / ENERGY_REGEN_SECONDS
	if ticks > 0:
		energy = mini(energy + ticks, energy_max)
		energy_updated_at += ticks * ENERGY_REGEN_SECONDS
	if energy >= energy_max:
		energy_updated_at = now_unix

# ---------------------------------------------------------------- heroes

func add_hero(hero_id: String) -> HeroInstance:
	var h := HeroInstance.create(hero_id)
	if h == null:
		return null
	h.uid = new_uid("h")
	heroes[h.uid] = h
	return h


func get_hero(uid: String) -> HeroInstance:
	return heroes.get(uid)


func remove_hero(uid: String) -> bool:
	var h: HeroInstance = heroes.get(uid)
	if h == null or h.locked:
		return false
	for slot in h.equipped.keys():
		unequip(uid, int(slot))
	for t in teams.keys():
		teams[t].erase(uid)
	heroes.erase(uid)
	return true


func add_xp(uid: String, amount: int) -> int:
	var h := get_hero(uid)
	return h.add_xp(amount) if h != null else 0


## Promotes `uid` using `fodder_uids` (same star count, not locked, not the target).
func promote(uid: String, fodder_uids: Array) -> bool:
	var h := get_hero(uid)
	if h == null or not h.can_promote():
		return false
	if fodder_uids.size() != h.fodder_needed():
		return false
	var seen := {}
	for f in fodder_uids:
		var fh := get_hero(str(f))
		if fh == null or fh == h or fh.locked or fh.stars != h.stars or seen.has(f):
			return false
		seen[f] = true
	var cost := {"gold": int(Progression.PROMOTION_GOLD.get(h.stars, 0))}
	if not spend(cost):
		return false
	for f in fodder_uids:
		remove_hero(str(f))
	h.promote()
	return true


func awaken(uid: String) -> bool:
	var h := get_hero(uid)
	if h == null or not h.can_awaken():
		return false
	if not spend(h.awakening_cost()):
		return false
	h.awaken()
	return true


## Consumes a duplicate copy of the same hero to raise the target's bond level.
func merge_bond(target_uid: String, dupe_uid: String) -> bool:
	var t := get_hero(target_uid)
	var d := get_hero(dupe_uid)
	if t == null or d == null or t == d or d.locked or t.hero_id != d.hero_id:
		return false
	if t.bond_level >= Progression.MAX_BOND:
		return false
	remove_hero(dupe_uid)
	return t.add_bond()


func upgrade_skill(uid: String, skill_index: int, cost: Dictionary = {}) -> bool:
	var h := get_hero(uid)
	if h == null or skill_index < 0 or skill_index >= h.skill_levels.size():
		return false
	if h.skill_levels[skill_index] >= h.data().skills[skill_index].max_level():
		return false
	if not spend(cost):
		return false
	h.set_skill_level(skill_index, h.skill_levels[skill_index] + 1)
	return true

# ---------------------------------------------------------------- gear

func add_gear(g: Gear) -> Gear:
	g.uid = new_uid("g")
	gear[g.uid] = g
	return g


func get_gear(uid: String) -> Gear:
	return gear.get(uid)


func gear_owner(gear_uid: String) -> String:
	for uid in heroes.keys():
		for slot in heroes[uid].equipped.keys():
			if heroes[uid].equipped[slot] == gear_uid:
				return uid
	return ""


func equip(hero_uid: String, gear_uid: String) -> bool:
	var h := get_hero(hero_uid)
	var g := get_gear(gear_uid)
	if h == null or g == null:
		return false
	var owner := gear_owner(gear_uid)
	if owner != "" and owner != hero_uid:
		unequip(owner, int(g.slot))
	h.equipped[int(g.slot)] = gear_uid
	return true


func unequip(hero_uid: String, slot: int) -> bool:
	var h := get_hero(hero_uid)
	if h == null or not h.equipped.has(slot):
		return false
	h.equipped.erase(slot)
	return true


func equipped_items(hero_uid: String) -> Array:
	var h := get_hero(hero_uid)
	var out: Array = []
	if h == null:
		return out
	for slot in h.equipped.keys():
		var g := get_gear(h.equipped[slot])
		if g != null:
			out.append(g)
	return out


func hero_stats(hero_uid: String) -> Dictionary:
	var h := get_hero(hero_uid)
	return h.compute_stats(equipped_items(hero_uid)) if h != null else Stats.empty()

# ---------------------------------------------------------------- teams

func set_team(preset: String, uids: Array) -> bool:
	if uids.size() < 1 or uids.size() > 4:
		return false
	var clean: Array = []
	for u in uids:
		if get_hero(str(u)) == null or clean.has(str(u)):
			return false
		clean.append(str(u))
	teams[preset] = clean
	return true


## Builds battle units for a team, applying gear, skill levels and team-wide bonds.
func build_team(uids: Array, team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var members: Array[HeroInstance] = []
	for u in uids:
		var h := get_hero(str(u))
		if h != null:
			members.append(h)
	for i in members.size():
		var h := members[i]
		var items := equipped_items(h.uid)
		var stats := h.compute_stats(items)
		for other in members:
			Progression.apply_bond(stats, other.data().role, other.bond_level)
		var unit := BattleUnit.new(h.data(), team, i, h.level, {}, GearSets.bonuses(items)["flags"])
		unit.base_stats = stats
		unit.hp = unit.max_hp()
		for s in h.skill_levels.size():
			unit.skill_levels[s] = h.skill_levels[s]
		out.append(unit)
	return out

# ---------------------------------------------------------------- serialisation

func to_dict() -> Dictionary:
	var hs := {}
	for uid in heroes.keys():
		hs[uid] = heroes[uid].to_dict()
	var gs := {}
	for uid in gear.keys():
		gs[uid] = gear[uid].to_dict()
	return {
		"name": name, "created_at": created_at, "gold": gold, "crystals": crystals,
		"mileage": mileage, "energy": energy, "energy_max": energy_max,
		"energy_updated_at": energy_updated_at, "materials": materials.duplicate(),
		"heroes": hs, "gear": gs, "teams": teams.duplicate(true), "flags": flags.duplicate(true),
		"next_uid": _next_uid,
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new(int(d.get("created_at", 0)))
	p.name = str(d.get("name", "Player"))
	p.gold = int(d.get("gold", 0))
	p.crystals = int(d.get("crystals", 0))
	p.mileage = int(d.get("mileage", 0))
	p.energy = int(d.get("energy", 0))
	p.energy_max = int(d.get("energy_max", ENERGY_MAX_BASE))
	p.energy_updated_at = int(d.get("energy_updated_at", 0))
	for k in d.get("materials", {}).keys():
		p.materials[k] = int(d["materials"][k])
	for uid in d.get("heroes", {}).keys():
		var h := HeroInstance.from_dict(d["heroes"][uid])
		if h != null:
			p.heroes[uid] = h
	for uid in d.get("gear", {}).keys():
		p.gear[uid] = Gear.from_dict(d["gear"][uid])
	for t in d.get("teams", {}).keys():
		var arr: Array = []
		for u in d["teams"][t]:
			arr.append(str(u))
		p.teams[t] = arr
	p.flags = d.get("flags", {}).duplicate(true)
	p._next_uid = int(d.get("next_uid", 1))
	return p
