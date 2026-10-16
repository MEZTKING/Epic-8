class_name BattleUnit
extends RefCounted
## Runtime state of one combatant during a battle.

var data: HeroData
var team: int                 # 0 = player, 1 = enemy
var slot: int                 # position in team
var level: int
var base_stats: Dictionary    # level-scaled hero stats + gear (no buffs)
var hp: float
var gauge: float = 0.0        # initiative gauge, 0..100; acts at 100
var cooldowns: Dictionary = {}   # skill index -> turns remaining
var effects: Array[Dictionary] = []  # {"id": String, "turns": int, ["source"], ["shield"]}
var alive: bool = true
var flags: Array[String] = []     # gear-set behaviour flags: "lifesteal_20", "counter_20", "dual_20"
var skill_levels: Array[int] = [] # enhancement level per skill index
var last_absorbed: float = 0.0    # shield absorption from the most recent take_damage
var _skill_cache: Array = []


func _init(p_data: HeroData, p_team: int, p_slot: int, p_level: int = 60, gear_stats: Dictionary = {}, p_flags: Array[String] = []) -> void:
	data = p_data
	team = p_team
	slot = p_slot
	level = p_level
	var lv := Stats.at_level(p_data.max_stats, p_level)
	base_stats = Stats.add(lv, gear_stats) if not gear_stats.is_empty() else lv
	hp = base_stats["hp"]
	flags = p_flags.duplicate()
	for _i in p_data.skills.size():
		skill_levels.append(0)
	apply_flag_penalties()


## Permanent stat changes from gear flags (e.g. Reckless −10% max HP).
func apply_flag_penalties() -> void:
	var reckless := gear_flag_value("reckless")
	if reckless > 0.0 and not _penalties_applied:
		base_stats["hp"] = roundf(float(base_stats["hp"]) * (1.0 - reckless))
		hp = minf(hp, base_stats["hp"])
		_penalties_applied = true


var _penalties_applied := false


func has_any_debuff() -> bool:
	for e in effects:
		if EffectCatalog.is_debuff(e["id"]):
			return true
	return false


func display_name() -> String:
	return "%s(%s%d)" % [data.name, "P" if team == 0 else "E", slot]


func max_hp() -> float:
	return base_stats["hp"]


## The skill at `index` with this unit's enhancement level applied.
func skill(index: int) -> SkillData:
	if _skill_cache.size() != data.skills.size():
		_skill_cache.clear()
		for i in data.skills.size():
			_skill_cache.append(data.skills[i].at_level(skill_levels[i]))
	return _skill_cache[index]


func set_skill_level(index: int, lvl: int) -> void:
	skill_levels[index] = clampi(lvl, 0, data.skills[index].max_level())
	_skill_cache.clear()


## Value of a gear flag such as "lifesteal_20" -> 0.2; 0.0 if absent.
func gear_flag_value(prefix: String) -> float:
	var best := 0.0
	for f in flags:
		if f.begins_with(prefix + "_"):
			best = maxf(best, float(f.substr(prefix.length() + 1)) / 100.0)
	return best


## Stat after active buff/debuff multipliers.
func stat(key: String) -> float:
	var base := float(base_stats[key])
	var mult := 1.0
	var flat := 0.0
	for e in effects:
		var mods: Dictionary = EffectCatalog.get_effect(e["id"]).get("mods", {})
		if mods.has(key):
			if key in Stats.PERCENT_KEYS:
				flat += float(mods[key])
			else:
				mult += float(mods[key])
	return base * maxf(mult, 0.0) + flat


func has_flag(flag: String) -> bool:
	for e in effects:
		if flag in EffectCatalog.get_effect(e["id"]).get("flags", []):
			return true
	return false


func has_effect(id: String) -> bool:
	for e in effects:
		if e["id"] == id:
			return true
	return false


func get_effect(id: String) -> Dictionary:
	for e in effects:
		if e["id"] == id:
			return e
	return {}


## Adds or refreshes an effect. Returns false if blocked (immunity vs debuff).
func add_effect(id: String, turns: int, source: BattleUnit = null) -> bool:
	if EffectCatalog.is_debuff(id) and has_flag("immune"):
		return false
	# Sources are stored by team/slot (not object reference) to avoid cycles.
	for e in effects:
		if e["id"] == id:
			e["turns"] = maxi(int(e["turns"]), turns)
			if source != null:
				e["source"] = {"team": source.team, "slot": source.slot}
			return true
	var entry := {"id": id, "turns": turns}
	if source != null:
		entry["source"] = {"team": source.team, "slot": source.slot}
	effects.append(entry)
	return true


## Barrier: absorbs `amount` damage. A new barrier replaces a weaker one.
func add_barrier(amount: float, turns: int) -> void:
	var e := get_effect("barrier")
	if e.is_empty():
		effects.append({"id": "barrier", "turns": turns, "shield": amount})
	else:
		e["shield"] = maxf(float(e["shield"]), amount)
		e["turns"] = maxi(int(e["turns"]), turns)


func shield_value() -> float:
	return float(get_effect("barrier").get("shield", 0.0))


func remove_effect(id: String) -> void:
	for i in range(effects.size() - 1, -1, -1):
		if effects[i]["id"] == id:
			effects.remove_at(i)


## Removes up to `count` buffs (newest first). Returns the removed ids.
func remove_buffs(count: int) -> Array[String]:
	return _remove_kind(count, false)


## Removes up to `count` debuffs (newest first). Returns the removed ids.
func remove_debuffs(count: int) -> Array[String]:
	return _remove_kind(count, true)


func _remove_kind(count: int, debuffs: bool) -> Array[String]:
	var removed: Array[String] = []
	for i in range(effects.size() - 1, -1, -1):
		if removed.size() >= count:
			break
		if EffectCatalog.is_debuff(effects[i]["id"]) == debuffs:
			removed.append(effects[i]["id"])
			effects.remove_at(i)
	return removed


func skill_ready(index: int) -> bool:
	return int(cooldowns.get(index, 0)) <= 0


func set_cooldown(index: int, turns: int) -> void:
	if turns > 0:
		cooldowns[index] = turns


## Applies damage, barriers first. Returns damage actually taken from HP.
func take_damage(amount: float) -> float:
	last_absorbed = 0.0
	var remaining := maxf(amount, 0.0)
	var b := get_effect("barrier")
	if not b.is_empty():
		var absorb := minf(float(b["shield"]), remaining)
		b["shield"] = float(b["shield"]) - absorb
		remaining -= absorb
		last_absorbed = absorb
		if float(b["shield"]) <= 0.0:
			remove_effect("barrier")
	var dealt := minf(remaining, hp)
	hp -= dealt
	if hp <= 0.0:
		hp = 0.0
		alive = false
		effects.clear()
	return dealt


func heal(amount: float) -> float:
	if not alive or has_flag("no_heal"):
		return 0.0
	var healed := minf(amount, max_hp() - hp)
	hp += healed
	return healed


func push_gauge(amount: float) -> void:
	gauge = clampf(gauge + amount, 0.0, 100.0)


## Called when this unit's turn ends: tick cooldowns and effect durations.
func end_turn() -> void:
	for k in cooldowns.keys():
		cooldowns[k] = maxi(int(cooldowns[k]) - 1, 0)
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["turns"] = int(effects[i]["turns"]) - 1
		if int(effects[i]["turns"]) <= 0:
			effects.remove_at(i)


## Serialisable description sufficient to rebuild this unit at battle start.
func to_spec() -> Dictionary:
	return {
		"hero_id": data.id, "team": team, "slot": slot, "level": level,
		"base_stats": base_stats.duplicate(), "flags": Array(flags),
		"skill_levels": Array(skill_levels),
	}


static func from_spec(d: Dictionary) -> BattleUnit:
	var u := BattleUnit.new(HeroDB.get_hero(str(d["hero_id"])), int(d["team"]), int(d["slot"]), int(d.get("level", 60)))
	if d.has("base_stats"):
		u.base_stats = Stats.from_dict(d["base_stats"])
		u.hp = u.max_hp()
	u.flags.clear()
	for f in d.get("flags", []):
		u.flags.append(str(f))
	var levels: Array = d.get("skill_levels", [])
	for i in mini(levels.size(), u.skill_levels.size()):
		u.skill_levels[i] = int(levels[i])
	return u
