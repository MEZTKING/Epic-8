class_name BattleEngine
extends RefCounted
## Deterministic turn-based battle driven by an initiative gauge.
## Every unit fills its gauge at a rate equal to its Speed; the first unit to
## reach 100 acts, then its gauge resets to 0. Fully seedable for tests/replays.

signal turn_started(unit: BattleUnit)
signal action_resolved(unit: BattleUnit, skill: SkillData, results: Array)
signal unit_defeated(unit: BattleUnit)
signal battle_ended(winner: int)

const GAUGE_MAX := 100.0
const RESOLVE_PER_TURN := 10
const RESOLVE_MAX := 100

var rng := RandomNumberGenerator.new()
var units: Array[BattleUnit] = []
var turn_count: int = 0
var winner: int = -1            # -1 = ongoing, 0 = player, 1 = enemy, 2 = draw/timeout
var log_lines: PackedStringArray = []
var resolve: Array[int] = [0, 0]   # per-team Resolve pool used to empower skills
var auto_resolve := true           # AI spends Resolve automatically when it can


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


func setup(player_team: Array[BattleUnit], enemy_team: Array[BattleUnit]) -> void:
	units.clear()
	for u in player_team:
		u.team = 0
		units.append(u)
	for u in enemy_team:
		u.team = 1
		units.append(u)
	turn_count = 0
	winner = -1
	log_lines.clear()
	resolve = [0, 0]


func add_log(msg: String) -> void:
	log_lines.append(msg)


func living(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


func is_over() -> bool:
	return winner != -1


## Runs the battle to completion (or max_turns). Returns winner.
func run(max_turns: int = 300) -> int:
	while not is_over() and turn_count < max_turns:
		step()
	if not is_over():
		winner = 2
		add_log("Battle timed out after %d turns." % turn_count)
		battle_ended.emit(winner)
	return winner


## Advances time until one unit reaches the gauge cap and returns it.
func next_actor() -> BattleUnit:
	var best: BattleUnit = null
	var best_time := INF
	for u in units:
		if not u.alive:
			continue
		var spd := maxf(u.stat("spd"), 1.0)
		var t := (GAUGE_MAX - u.gauge) / spd
		# Tie-break: higher speed first, then player team, then slot order.
		if t < best_time - 0.000001 or (absf(t - best_time) <= 0.000001 and best != null and _tie_break(u, best)):
			best = u
			best_time = t
	if best == null:
		return null
	for u in units:
		if u.alive:
			u.gauge = minf(u.gauge + u.stat("spd") * best_time, GAUGE_MAX)
	return best


func _tie_break(a: BattleUnit, b: BattleUnit) -> bool:
	if a.stat("spd") != b.stat("spd"):
		return a.stat("spd") > b.stat("spd")
	if a.team != b.team:
		return a.team < b.team
	return a.slot < b.slot


## Executes exactly one unit turn.
func step() -> void:
	if is_over():
		return
	var actor := next_actor()
	if actor == null:
		return
	turn_count += 1
	actor.gauge = 0.0
	turn_started.emit(actor)

	# Damage-over-time ticks at start of the victim's turn.
	_apply_dots(actor)
	if not actor.alive:
		_check_end()
		return

	if actor.has_flag("skip_turn"):
		add_log("T%d %s is stunned and skips the turn." % [turn_count, actor.display_name()])
		actor.end_turn()
		_check_end()
		return

	resolve[actor.team] = mini(resolve[actor.team] + RESOLVE_PER_TURN, RESOLVE_MAX)
	var skill_index := choose_skill_index(actor)
	var skill := actor.data.skills[skill_index]
	var empowered := false
	if auto_resolve and skill.resolve_cost > 0 and resolve[actor.team] >= skill.resolve_cost:
		resolve[actor.team] -= skill.resolve_cost
		empowered = true
	var targets := choose_targets(actor, skill)
	use_skill(actor, skill_index, targets, empowered)
	actor.end_turn()
	_check_end()


func _apply_dots(unit: BattleUnit) -> void:
	for e in unit.effects.duplicate():
		var dot := float(EffectCatalog.get_effect(e["id"]).get("dot", 0.0))
		if dot > 0.0:
			var dmg := roundf(unit.max_hp() * dot)
			unit.take_damage(dmg)
			add_log("T%d %s takes %d %s damage." % [turn_count, unit.display_name(), dmg, EffectCatalog.get_effect(e["id"])["name"]])
			if not unit.alive:
				add_log("T%d %s is defeated." % [turn_count, unit.display_name()])
				unit_defeated.emit(unit)
				return


## Default AI: use the highest-numbered ready skill. Healers prefer heals when
## an ally is below 50% HP; otherwise skip pure-heal skills if nobody is hurt.
func choose_skill_index(actor: BattleUnit) -> int:
	var allies := living(actor.team)
	var anyone_hurt := false
	for a in allies:
		if a.hp < a.max_hp() * 0.5:
			anyone_hurt = true
	for i in range(actor.data.skills.size() - 1, -1, -1):
		if not actor.skill_ready(i):
			continue
		var s := actor.data.skills[i]
		if s.is_heal() and not s.is_damage() and not anyone_hurt and i > 0:
			continue
		return i
	return 0


func choose_targets(actor: BattleUnit, skill: SkillData) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var enemies := living(1 - actor.team)
	var allies := living(actor.team)
	match skill.target:
		"enemy":
			# A provoked unit must attack whoever provoked it (if still alive).
			var forced: BattleUnit = null
			for e in actor.effects:
				if e["id"] == "provoke" and e.has("source") and e["source"].alive:
					forced = e["source"]
			if forced != null:
				out.append(forced)
			elif enemies.size() > 0:
				# Default AI: attack the lowest-HP enemy.
				var pick := enemies[0]
				for e in enemies:
					if e.hp < pick.hp:
						pick = e
				out.append(pick)
		"all_enemies":
			out.append_array(enemies)
		"self":
			out.append(actor)
		"ally", "lowest_hp_ally":
			if allies.size() > 0:
				var pick := allies[0]
				for a in allies:
					if a.hp / a.max_hp() < pick.hp / pick.max_hp():
						pick = a
				out.append(pick)
		"all_allies":
			out.append_array(allies)
	return out


## Resolves a skill. `results` is an Array of Dictionaries for UI consumption.
func use_skill(actor: BattleUnit, skill_index: int, targets: Array[BattleUnit], empowered := false) -> Array:
	var skill := actor.data.skills[skill_index]
	var results: Array = []
	actor.set_cooldown(skill_index, skill.cooldown)
	var tag := " [Resolve]" if empowered else ""
	add_log("T%d %s uses %s%s." % [turn_count, actor.display_name(), skill.name, tag])

	# Self-targeted pre-effects (e.g. guaranteed crit).
	var force_crit := false
	for ef in skill.effects:
		if ef.get("target", "hit") == "self_before":
			if ef["id"] == "crit_up":
				force_crit = true
			else:
				actor.add_effect(ef["id"], int(ef.get("turns", 1)))

	for t in targets:
		var r := {"target": t, "damage": 0.0, "heal": 0.0, "crit": false, "effects": []}
		if skill.is_damage() and t.team != actor.team:
			var d := DamageCalc.compute(actor, t, skill, rng, force_crit)
			var dmg: float = d["damage"] * (1.25 if empowered else 1.0)
			var dealt := t.take_damage(dmg)
			r["damage"] = dealt
			r["crit"] = d["crit"]
			add_log("  -> %s takes %d%s%s." % [t.display_name(), dealt, " CRIT" if d["crit"] else "", " (advantage)" if d["advantage"] > 0 else ""])
			if not t.alive:
				add_log("  -> %s is defeated." % t.display_name())
				unit_defeated.emit(t)
		if skill.is_heal():
			var heal_target := t
			if skill.targets_enemies():
				heal_target = _lowest_hp_ally(actor)
			if heal_target != null:
				var healed := heal_target.heal(heal_target.max_hp() * skill.heal_percent)
				if healed > 0.0:
					r["heal"] = healed
					add_log("  -> %s heals %d." % [heal_target.display_name(), healed])
		if skill.gauge_push > 0.0 and t.team == actor.team and t.alive:
			t.push_gauge(skill.gauge_push)
		for ef in skill.effects:
			_apply_effect(actor, t, ef, r)
		results.append(r)
	action_resolved.emit(actor, skill, results)
	return results


func _lowest_hp_ally(actor: BattleUnit) -> BattleUnit:
	var pick: BattleUnit = null
	for a in living(actor.team):
		if pick == null or a.hp / a.max_hp() < pick.hp / pick.max_hp():
			pick = a
	return pick


func _apply_effect(actor: BattleUnit, hit_target: BattleUnit, ef: Dictionary, r: Dictionary) -> void:
	var id: String = ef["id"]
	var turns := int(ef.get("turns", 1))
	var chance := float(ef.get("chance", 1.0))
	var where: String = ef.get("target", "hit")
	var victims: Array[BattleUnit] = []
	match where:
		"hit": victims.append(hit_target)
		"self": victims.append(actor)
		"self_before": return
		"all_allies": victims.append_array(living(actor.team))
		"all_enemies": victims.append_array(living(1 - actor.team))
		"highest_atk_enemy":
			var pick: BattleUnit = null
			for e in living(1 - actor.team):
				if pick == null or e.stat("atk") > pick.stat("atk"):
					pick = e
			if pick != null:
				victims.append(pick)
	for v in victims:
		if not v.alive:
			continue
		var is_debuff := EffectCatalog.is_debuff(id)
		var lands := true
		if is_debuff:
			lands = DamageCalc.debuff_lands(chance, actor, v, rng)
		elif chance < 1.0:
			lands = rng.randf() < chance
		if lands and v.add_effect(id, turns, actor):
			r["effects"].append(id)
			add_log("  -> %s gains %s (%d)." % [v.display_name(), EffectCatalog.get_effect(id)["name"], turns])
		elif is_debuff:
			add_log("  -> %s resists %s." % [v.display_name(), EffectCatalog.get_effect(id)["name"]])


func _check_end() -> void:
	if winner != -1:
		return
	var p := living(0).size()
	var e := living(1).size()
	if p == 0 and e == 0:
		winner = 2
	elif e == 0:
		winner = 0
	elif p == 0:
		winner = 1
	if winner != -1:
		add_log("Battle over after %d turns. Winner: %s" % [turn_count, ["Player", "Enemy", "Draw"][winner]])
		battle_ended.emit(winner)
