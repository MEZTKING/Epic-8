class_name BattleEngine
extends RefCounted
## Deterministic turn-based battle driven by an initiative gauge.
## Every unit fills its gauge at a rate equal to its Speed; the first unit to
## reach 100 acts, then its gauge resets to 0. Fully seedable for tests/replays.
##
## Teams listed in `manual_teams` pause the engine for input: `step()` returns
## false with `awaiting_input` set, and the UI calls `submit_action(...)`.
## Every executed action is appended to `decisions`, so `to_replay()` captures
## a complete, replayable record of the battle.

signal turn_started(unit: BattleUnit)
signal input_requested(unit: BattleUnit)
signal action_resolved(unit: BattleUnit, skill: SkillData, results: Array)
signal unit_defeated(unit: BattleUnit)
signal battle_ended(winner: int)

const GAUGE_MAX := 100.0
const RESOLVE_PER_TURN := 10
const RESOLVE_MAX := 100
const RESOLVE_DAMAGE_MULT := 1.25

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var units: Array[BattleUnit] = []
var turn_count: int = 0
var winner: int = -1            # -1 = ongoing, 0 = player, 1 = enemy, 2 = draw/timeout
var log_lines: PackedStringArray = []
var resolve: Array[int] = [0, 0]   # per-team Resolve pool used to empower skills
var auto_resolve := true           # AI spends Resolve automatically when it can
var manual_teams: Array[int] = []
var awaiting_input := false
var current_actor: BattleUnit = null
var decisions: Array[Dictionary] = []


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	rng.seed = p_seed


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
	decisions.clear()
	resolve = [0, 0]
	awaiting_input = false
	current_actor = null


func add_log(msg: String) -> void:
	log_lines.append(msg)


func living(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


func unit_at(team: int, slot: int) -> BattleUnit:
	for u in units:
		if u.team == team and u.slot == slot:
			return u
	return null


func is_over() -> bool:
	return winner != -1


## Runs until the battle ends, input is required, or max_turns is hit.
func run(max_turns: int = 300) -> int:
	while not is_over() and turn_count < max_turns:
		if not step():
			break
	if not is_over() and not awaiting_input:
		winner = 2
		add_log("Battle timed out after %d turns." % turn_count)
		battle_ended.emit(winner)
	return winner


## Serialisable record: seed, both teams, every decision taken.
func to_replay() -> Dictionary:
	var p: Array = []
	var e: Array = []
	for u in units:
		(p if u.team == 0 else e).append(u.to_spec())
	return {"seed": seed_value, "player": p, "enemy": e, "decisions": decisions.duplicate(true)}


# ---------------------------------------------------------------- turn order

## Advances time until one unit reaches the gauge cap and returns it.
func next_actor() -> BattleUnit:
	var best: BattleUnit = null
	var best_time := INF
	for u in units:
		if not u.alive:
			continue
		var spd := maxf(u.stat("spd"), 1.0)
		var t := (GAUGE_MAX - u.gauge) / spd
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


## Executes one unit turn. Returns false if the battle is over or input is needed.
func step() -> bool:
	if is_over() or awaiting_input:
		return false
	var actor := next_actor()
	if actor == null:
		return false
	turn_count += 1
	actor.gauge = 0.0
	turn_started.emit(actor)

	_apply_dots(actor)
	if not actor.alive:
		_check_end()
		return true

	if actor.has_flag("skip_turn"):
		add_log("T%d %s is stunned and skips the turn." % [turn_count, actor.display_name()])
		actor.end_turn()
		_check_end()
		return true

	resolve[actor.team] = mini(resolve[actor.team] + RESOLVE_PER_TURN, RESOLVE_MAX)
	_fire_passives("on_turn_start", actor, actor, actor)

	if actor.team in manual_teams:
		awaiting_input = true
		current_actor = actor
		input_requested.emit(actor)
		return false

	var skill_index := choose_skill_index(actor)
	var skill := actor.skill(skill_index)
	var empower := auto_resolve and skill.resolve_cost > 0 and resolve[actor.team] >= skill.resolve_cost
	_execute(actor, skill_index, choose_target(actor, skill), empower)
	return true


## Player input for the unit in `current_actor`. Returns false if invalid.
func submit_action(skill_index: int, target: BattleUnit, empower: bool = false) -> bool:
	if not awaiting_input or current_actor == null:
		return false
	var actor := current_actor
	if skill_index < 0 or skill_index >= actor.data.skills.size():
		return false
	var skill := actor.skill(skill_index)
	if skill.passive or not actor.skill_ready(skill_index):
		return false
	if empower and (skill.resolve_cost <= 0 or resolve[actor.team] < skill.resolve_cost):
		return false
	if skill.is_single_target():
		if skill.target == "self":
			target = actor
		if target == null or not target.alive:
			return false
		var want_enemy := skill.targets_enemies()
		if (target.team != actor.team) != want_enemy:
			return false
		var forced := provoker_of(actor)
		if want_enemy and forced != null:
			target = forced
	else:
		target = null
	awaiting_input = false
	current_actor = null
	_execute(actor, skill_index, target, empower)
	return true


func _execute(actor: BattleUnit, skill_index: int, target: BattleUnit, empower: bool) -> void:
	var skill := actor.skill(skill_index)
	decisions.append({
		"turn": turn_count, "skill": skill_index,
		"target_team": target.team if target != null else -1,
		"target_slot": target.slot if target != null else -1,
		"empower": empower,
	})
	if empower:
		resolve[actor.team] -= skill.resolve_cost
	use_skill(actor, skill_index, resolve_targets(actor, skill, target), empower)
	if skill.extra_turn and actor.alive:
		actor.gauge = GAUGE_MAX
		add_log("  -> %s gains an extra turn." % actor.display_name())
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


# ---------------------------------------------------------------- AI

## Default AI: use the highest-numbered ready active skill. Pure heals are
## skipped unless an ally is below 50% HP.
func choose_skill_index(actor: BattleUnit) -> int:
	var anyone_hurt := false
	for a in living(actor.team):
		if a.hp < a.max_hp() * 0.5:
			anyone_hurt = true
	var fallback := 0
	for i in range(actor.data.skills.size() - 1, -1, -1):
		var s := actor.skill(i)
		if s.passive:
			continue
		fallback = i
		if not actor.skill_ready(i):
			continue
		if s.is_heal() and not s.is_damage() and not anyone_hurt and i > 0:
			continue
		return i
	return fallback


## The unit that provoked `actor`, if that effect is active and the source lives.
func provoker_of(actor: BattleUnit) -> BattleUnit:
	var e := actor.get_effect("provoke")
	if e.has("source"):
		var src := unit_at(int(e["source"]["team"]), int(e["source"]["slot"]))
		if src != null and src.alive:
			return src
	return null


## Picks a single target for single-target skills; null for area skills.
func choose_target(actor: BattleUnit, skill: SkillData) -> BattleUnit:
	match skill.target:
		"enemy":
			var forced := provoker_of(actor)
			if forced != null:
				return forced
			var pick: BattleUnit = null
			for e in living(1 - actor.team):
				if pick == null or e.hp < pick.hp:
					pick = e
			return pick
		"self":
			return actor
		"ally":
			return _lowest_hp_ally(actor)
	return null


func resolve_targets(actor: BattleUnit, skill: SkillData, target: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	match skill.target:
		"all_enemies":
			out.append_array(living(1 - actor.team))
		"all_allies":
			out.append_array(living(actor.team))
		_:
			if target != null:
				out.append(target)
	return out


func _lowest_hp_ally(actor: BattleUnit) -> BattleUnit:
	var pick: BattleUnit = null
	for a in living(actor.team):
		if pick == null or a.hp / a.max_hp() < pick.hp / pick.max_hp():
			pick = a
	return pick


# ---------------------------------------------------------------- resolution

## Resolves a skill. `nested` marks counterattacks and dual attacks, which
## do not set cooldowns and do not trigger further reactions.
func use_skill(actor: BattleUnit, skill_index: int, targets: Array[BattleUnit], empowered := false, nested := false) -> Array:
	var skill := actor.skill(skill_index)
	var results: Array = []
	if not nested:
		actor.set_cooldown(skill_index, skill.cooldown)
	var tag := " [Resolve]" if empowered else ""
	add_log("T%d %s uses %s%s." % [turn_count, actor.display_name(), skill.name, tag])

	var force_crit := false
	for ef in skill.effects:
		if ef.get("target", "hit") == "self_before":
			if ef.get("id", "") == "crit_up":
				force_crit = true
			else:
				actor.add_effect(ef["id"], int(ef.get("turns", 1)))

	var total_damage := 0.0
	for t in targets:
		var r := {"target": t, "damage": 0.0, "absorbed": 0.0, "heal": 0.0, "crit": false, "effects": []}
		if skill.is_damage() and t.team != actor.team:
			var d := DamageCalc.compute(actor, t, skill, rng, force_crit)
			var dmg: float = d["damage"] * (RESOLVE_DAMAGE_MULT if empowered else 1.0)
			var dealt := t.take_damage(dmg)
			total_damage += dealt
			r["damage"] = dealt
			r["absorbed"] = t.last_absorbed
			r["crit"] = d["crit"]
			var shield_note := " (barrier absorbs %d)" % t.last_absorbed if t.last_absorbed > 0.0 else ""
			add_log("  -> %s takes %d%s%s%s." % [t.display_name(), dealt, " CRIT" if d["crit"] else "", " (advantage)" if d["advantage"] > 0 else "", shield_note])
			if not t.alive:
				add_log("  -> %s is defeated." % t.display_name())
				unit_defeated.emit(t)
				_fire_passives("on_kill", actor, t, t)
			else:
				_fire_passives("on_hit", t, actor, t)
				for ally in living(t.team):
					if ally != t:
						_fire_passives("on_ally_attacked", ally, actor, t)
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

	var lifesteal := actor.gear_flag_value("lifesteal")
	if lifesteal > 0.0 and total_damage > 0.0 and actor.alive:
		var healed := actor.heal(total_damage * lifesteal)
		if healed > 0.0:
			add_log("  -> %s drains %d." % [actor.display_name(), healed])
	action_resolved.emit(actor, skill, results)

	if not nested and skill.is_damage() and skill.is_single_target() and targets.size() == 1 and targets[0].team != actor.team:
		var t := targets[0]
		if t.alive and actor.alive:
			_try_counter(t, actor)
		if t.alive and actor.alive:
			_try_dual_attack(actor, t)
	return results


func _try_counter(defender: BattleUnit, attacker: BattleUnit) -> void:
	var c := defender.gear_flag_value("counter")
	if c <= 0.0 or defender.has_flag("skip_turn"):
		return
	if rng.randf() < c:
		add_log("  -> %s counterattacks!" % defender.display_name())
		use_skill(defender, 0, [attacker], false, true)


func _try_dual_attack(actor: BattleUnit, target: BattleUnit) -> void:
	for ally in living(actor.team):
		if ally == actor or ally.has_flag("skip_turn"):
			continue
		var d := ally.gear_flag_value("dual")
		if d > 0.0 and rng.randf() < d:
			add_log("  -> %s joins with a dual attack!" % ally.display_name())
			use_skill(ally, 0, [target], false, true)
			return


## Fires `owner`'s passives with the given trigger. `other` is the attacker
## (for on_hit / on_ally_attacked) or the slain unit (on_kill); `victim` is
## the ally that was attacked (on_ally_attacked).
func _fire_passives(trigger: String, owner: BattleUnit, other: BattleUnit, victim: BattleUnit) -> void:
	if not owner.alive:
		return
	for i in owner.data.skills.size():
		var s := owner.skill(i)
		if not s.passive or s.trigger != trigger or not owner.skill_ready(i):
			continue
		if s.chance < 1.0 and rng.randf() >= s.chance:
			continue
		owner.set_cooldown(i, s.cooldown)
		add_log("  -> %s's %s triggers." % [owner.display_name(), s.name])
		if s.heal_percent > 0.0:
			var healed := owner.heal(owner.max_hp() * s.heal_percent)
			if healed > 0.0:
				add_log("  -> %s heals %d." % [owner.display_name(), healed])
		if s.gauge_push > 0.0:
			owner.push_gauge(s.gauge_push)
		var r := {"effects": []}
		for ef in s.effects:
			_apply_effect(owner, other, ef, r, victim)


func _effect_victims(actor: BattleUnit, hit_target: BattleUnit, where: String, victim: BattleUnit) -> Array[BattleUnit]:
	var victims: Array[BattleUnit] = []
	match where:
		"hit":
			if hit_target != null:
				victims.append(hit_target)
		"self":
			victims.append(actor)
		"victim":
			if victim != null:
				victims.append(victim)
		"all_allies":
			victims.append_array(living(actor.team))
		"all_enemies":
			victims.append_array(living(1 - actor.team))
		"highest_atk_enemy":
			var pick: BattleUnit = null
			for e in living(1 - actor.team):
				if pick == null or e.stat("atk") > pick.stat("atk"):
					pick = e
			if pick != null:
				victims.append(pick)
	return victims


func _apply_effect(actor: BattleUnit, hit_target: BattleUnit, ef: Dictionary, r: Dictionary, victim: BattleUnit = null) -> void:
	var where: String = ef.get("target", "hit")
	if where == "self_before":
		return
	var chance := float(ef.get("chance", 1.0))
	var turns := int(ef.get("turns", 1))
	for v in _effect_victims(actor, hit_target, where, victim):
		if not v.alive:
			continue
		if ef.has("op"):
			_apply_op(actor, v, ef, chance, r)
			continue
		var id: String = ef["id"]
		var is_debuff := EffectCatalog.is_debuff(id)
		var lands := true
		if is_debuff:
			lands = DamageCalc.debuff_lands(chance, actor, v, rng)
		elif chance < 1.0:
			lands = rng.randf() < chance
		if not lands:
			if is_debuff:
				add_log("  -> %s resists %s." % [v.display_name(), EffectCatalog.get_effect(id)["name"]])
			continue
		if id == "barrier":
			var amount := roundf(actor.stat("atk") * float(ef.get("shield_atk_mult", 0.0)) + v.max_hp() * float(ef.get("shield_hp_pct", 0.0)))
			v.add_barrier(amount, turns)
			r["effects"].append(id)
			add_log("  -> %s gains a Barrier of %d (%d)." % [v.display_name(), amount, turns])
		elif v.add_effect(id, turns, actor):
			r["effects"].append(id)
			add_log("  -> %s gains %s (%d)." % [v.display_name(), EffectCatalog.get_effect(id)["name"], turns])


func _apply_op(actor: BattleUnit, v: BattleUnit, ef: Dictionary, chance: float, r: Dictionary) -> void:
	var count := int(ef.get("count", 1))
	match ef["op"]:
		"dispel":
			if v.team == actor.team or not DamageCalc.debuff_lands(chance, actor, v, rng):
				if v.team != actor.team:
					add_log("  -> %s resists dispel." % v.display_name())
				return
			var removed := v.remove_buffs(count)
			if removed.size() > 0:
				r["effects"].append("dispel")
				add_log("  -> %s loses %s." % [v.display_name(), ", ".join(removed)])
		"cleanse":
			if chance < 1.0 and rng.randf() >= chance:
				return
			var removed := v.remove_debuffs(count)
			if removed.size() > 0:
				r["effects"].append("cleanse")
				add_log("  -> %s is cleansed of %s." % [v.display_name(), ", ".join(removed)])


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
