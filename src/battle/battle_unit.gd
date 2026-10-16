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
var effects: Array[Dictionary] = []  # {"id": String, "turns": int}
var alive: bool = true


func _init(p_data: HeroData, p_team: int, p_slot: int, p_level: int = 60, gear_stats: Dictionary = {}) -> void:
	data = p_data
	team = p_team
	slot = p_slot
	level = p_level
	var lv := Stats.at_level(p_data.max_stats, p_level)
	base_stats = Stats.add(lv, gear_stats) if not gear_stats.is_empty() else lv
	hp = base_stats["hp"]


func display_name() -> String:
	return "%s(%s%d)" % [data.name, "P" if team == 0 else "E", slot]


func max_hp() -> float:
	return base_stats["hp"]


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


## Adds or refreshes an effect. Returns false if blocked (immunity vs debuff).
func add_effect(id: String, turns: int, source: BattleUnit = null) -> bool:
	if EffectCatalog.is_debuff(id) and has_flag("immune"):
		return false
	for e in effects:
		if e["id"] == id:
			e["turns"] = maxi(int(e["turns"]), turns)
			if source != null:
				e["source"] = source
			return true
	var entry := {"id": id, "turns": turns}
	if source != null:
		entry["source"] = source
	effects.append(entry)
	return true


func remove_effect(id: String) -> void:
	for i in range(effects.size() - 1, -1, -1):
		if effects[i]["id"] == id:
			effects.remove_at(i)


func skill_ready(index: int) -> bool:
	return int(cooldowns.get(index, 0)) <= 0


func set_cooldown(index: int, turns: int) -> void:
	if turns > 0:
		cooldowns[index] = turns


func take_damage(amount: float) -> float:
	var dealt := minf(maxf(amount, 0.0), hp)
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
