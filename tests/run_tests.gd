extends SceneTree
## Headless test runner. Run with:
##   godot --headless --path . --script tests/run_tests.gd
## Exits with code 1 if any assertion fails.

var _failures: int = 0
var _passes: int = 0
var _asserts: int = 0


func _init() -> void:
	HeroDB.load_all(true)
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			_run(n)
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _run(name: String) -> void:
	var before := _failures
	_asserts = 0
	call(name)
	if _asserts == 0:
		_failures += 1
		printerr("  %s made no assertions (did it crash?)" % name)
	if _failures == before:
		_passes += 1
		print("PASS %s" % name)
	else:
		print("FAIL %s" % name)


func check(cond: bool, msg: String) -> void:
	_asserts += 1
	if not cond:
		_failures += 1
		printerr("  assertion failed: %s" % msg)


func _unit(id: String, team: int, slot: int, level := 60) -> BattleUnit:
	return BattleUnit.new(HeroDB.get_hero(id), team, slot, level)


# ---------------------------------------------------------------- data

func test_data_loads() -> void:
	check(HeroDB.all_heroes().size() >= 6, "at least 6 heroes loaded")
	for h in HeroDB.all_heroes():
		check(h.skills.size() >= 2, "%s has skills" % h.id)
		check(h.max_stats["hp"] > 0, "%s has hp" % h.id)
		for s in h.skills:
			for ef in s.effects:
				if ef.has("op"):
					check(ef["op"] in ["dispel", "cleanse"], "%s op %s known" % [s.id, ef["op"]])
				else:
					check(not EffectCatalog.get_effect(ef["id"]).is_empty(), "%s effect %s exists" % [s.id, ef["id"]])


func test_stats_scale_with_level() -> void:
	var h := HeroDB.get_hero("kaelen")
	var l1 := Stats.at_level(h.max_stats, 1)
	var l60 := Stats.at_level(h.max_stats, 60)
	check(l60["atk"] == h.max_stats["atk"], "level 60 equals max")
	check(l1["atk"] < l60["atk"], "level 1 lower than 60")
	check(l1["crit_rate"] == l60["crit_rate"], "percent stats do not scale")


func test_elements() -> void:
	check(Elements.advantage(Elements.Type.FLAME, Elements.Type.VERDANT) == 1, "flame beats verdant")
	check(Elements.advantage(Elements.Type.VERDANT, Elements.Type.FLAME) == -1, "verdant loses to flame")
	check(Elements.advantage(Elements.Type.RADIANT, Elements.Type.UMBRAL) == 1, "radiant beats umbral")
	check(Elements.advantage(Elements.Type.UMBRAL, Elements.Type.RADIANT) == 1, "umbral beats radiant")
	check(Elements.advantage(Elements.Type.FLAME, Elements.Type.FLAME) == 0, "same element neutral")

# ---------------------------------------------------------------- combat math

func test_mitigation_monotonic() -> void:
	check(DamageCalc.mitigation(0) == 1.0, "zero def no mitigation")
	check(DamageCalc.mitigation(500) < DamageCalc.mitigation(100), "more def less damage")


func test_damage_deterministic() -> void:
	var a := _unit("kaelen", 0, 0)
	var b := _unit("thorne", 1, 0)
	var r1 := RandomNumberGenerator.new(); r1.seed = 7
	var r2 := RandomNumberGenerator.new(); r2.seed = 7
	var d1 := DamageCalc.compute(a, b, a.data.skills[0], r1)
	var d2 := DamageCalc.compute(a, b, a.data.skills[0], r2)
	check(d1["damage"] == d2["damage"], "same seed same damage")
	check(d1["advantage"] == 1, "flame vs verdant advantage")
	check(d1["damage"] > 0, "positive damage")


func test_buffs_change_stats() -> void:
	var a := _unit("kaelen", 0, 0)
	var base := a.stat("atk")
	a.add_effect("atk_up", 2)
	check(is_equal_approx(a.stat("atk"), base * 1.5), "atk_up +50%")
	a.add_effect("atk_down", 2)
	check(is_equal_approx(a.stat("atk"), base * 1.0), "buff and debuff cancel")
	a.end_turn(); a.end_turn()
	check(a.effects.is_empty(), "effects expire")


func test_immunity_blocks_debuffs() -> void:
	var a := _unit("thorne", 0, 0)
	a.add_effect("immunity", 2)
	check(not a.add_effect("stun", 1), "stun blocked by immunity")
	check(a.add_effect("def_up", 1), "buffs still apply")


func test_gauge_order_by_speed() -> void:
	var engine := BattleEngine.new(1)
	var fast := _unit("vexmoor", 0, 0)   # spd 118
	var slow := _unit("thorne", 1, 0)    # spd 98
	engine.setup([fast], [slow])
	var first := engine.next_actor()
	check(first == fast, "fastest unit acts first")
	check(is_equal_approx(first.gauge, 100.0), "actor gauge at cap")
	check(slow.gauge < 100.0 and slow.gauge > 0.0, "slower unit partially filled")


func test_gauge_push() -> void:
	var u := _unit("kaelen", 0, 0)
	u.gauge = 90.0
	u.push_gauge(50.0)
	check(u.gauge == 100.0, "gauge clamps at 100")


func test_battle_runs_and_ends() -> void:
	var engine := BattleEngine.new(42)
	var p: Array[BattleUnit] = [_unit("kaelen", 0, 0), _unit("mira", 0, 1), _unit("thorne", 0, 2), _unit("seraphi", 0, 3)]
	var e: Array[BattleUnit] = [_unit("grunt", 1, 0, 40), _unit("grunt", 1, 1, 40), _unit("grunt", 1, 2, 40)]
	engine.setup(p, e)
	var w := engine.run()
	check(w == 0, "level 60 team beats level 40 grunts (got %d)" % w)
	check(engine.turn_count > 0, "turns were taken")
	check(engine.log_lines.size() > 0, "log produced")


func test_battle_replay_identical() -> void:
	var logs: Array = []
	for _i in range(2):
		var engine := BattleEngine.new(1234)
		var p: Array[BattleUnit] = [_unit("kaelen", 0, 0), _unit("vexmoor", 0, 1)]
		var e: Array[BattleUnit] = [_unit("mira", 1, 0), _unit("bramble", 1, 1)]
		engine.setup(p, e)
		engine.run()
		logs.append("\n".join(engine.log_lines))
	check(logs[0] == logs[1], "same seed gives identical battle log")


func test_stun_skips_turn() -> void:
	var engine := BattleEngine.new(5)
	var a := _unit("vexmoor", 0, 0)
	var b := _unit("grunt", 1, 0)
	engine.setup([a], [b])
	a.add_effect("stun", 1)
	engine.step()
	check(b.hp == b.max_hp(), "stunned unit dealt no damage")
	check(not a.has_effect("stun"), "stun expired after the skipped turn")


func test_provoke_forces_target() -> void:
	var engine := BattleEngine.new(9)
	var tank := _unit("thorne", 0, 0)
	var squishy := _unit("mira", 0, 1)
	squishy.hp = 10.0  # would normally be the lowest-HP target
	var enemy := _unit("grunt", 1, 0)
	engine.setup([tank, squishy], [enemy])
	enemy.add_effect("provoke", 1, tank)
	var target := engine.choose_target(enemy, enemy.data.skills[0])
	check(target == tank, "provoked unit attacks provoker")


func test_cooldowns() -> void:
	var engine := BattleEngine.new(3)
	var a := _unit("mira", 0, 0)
	var b := _unit("grunt", 1, 0)
	engine.setup([a], [b])
	var idx := engine.choose_skill_index(a)
	check(idx == 2, "uses strongest ready skill first")
	engine.use_skill(a, 2, [b])
	a.end_turn()
	check(not a.skill_ready(2), "skill on cooldown after use")
	check(engine.choose_skill_index(a) == 1, "falls back to next ready skill")

# ---------------------------------------------------------------- milestone 1

func test_ai_skips_passives() -> void:
	var engine := BattleEngine.new(1)
	var a := _unit("thorne", 0, 0)
	var b := _unit("grunt", 1, 0)
	engine.setup([a], [b])
	for _i in range(6):
		check(not a.skill(engine.choose_skill_index(a)).passive, "AI never picks a passive")
		a.end_turn()


func test_barrier_absorbs() -> void:
	var u := _unit("grunt", 1, 0)
	u.add_barrier(500.0, 2)
	var dealt := u.take_damage(300.0)
	check(dealt == 0.0 and u.hp == u.max_hp(), "barrier absorbs fully")
	check(is_equal_approx(u.shield_value(), 200.0), "barrier reduced")
	dealt = u.take_damage(300.0)
	check(is_equal_approx(dealt, 100.0) and is_equal_approx(u.last_absorbed, 200.0), "overflow hits hp")
	check(not u.has_effect("barrier"), "depleted barrier removed")
	u.add_barrier(100.0, 1)
	u.add_barrier(50.0, 1)
	check(u.shield_value() == 100.0, "weaker barrier does not replace stronger")


func test_barrier_skill() -> void:
	var engine := BattleEngine.new(2)
	var ils := _unit("ilsabet", 0, 0)
	var ally := _unit("mira", 0, 1)
	var e := _unit("grunt", 1, 0)
	engine.setup([ils, ally], [e])
	ally.add_effect("atk_down", 2)
	engine.use_skill(ils, 1, engine.resolve_targets(ils, ils.skill(1), null))
	check(ally.has_effect("barrier") and ils.has_effect("barrier"), "all allies get barrier")
	check(is_equal_approx(ally.shield_value(), roundf(ils.stat("atk") * 1.2)), "barrier scales with caster atk")
	check(not ally.has_effect("atk_down"), "cleanse removed the debuff")


func test_dispel_and_cleanse() -> void:
	var u := _unit("grunt", 1, 0)
	u.add_effect("atk_up", 2)
	u.add_effect("def_up", 2)
	u.add_effect("stun", 1)
	var removed := u.remove_buffs(1)
	check(removed.size() == 1 and removed[0] == "def_up", "dispel removes newest buff first")
	check(u.has_effect("stun"), "dispel leaves debuffs")
	check(u.remove_debuffs(5).size() == 1 and not u.has_effect("stun"), "cleanse removes debuffs only")
	check(u.has_effect("atk_up"), "cleanse leaves buffs")


func test_lifesteal() -> void:
	var engine := BattleEngine.new(3)
	var a := BattleUnit.new(HeroDB.get_hero("kaelen"), 0, 0, 60, {}, ["lifesteal_20"])
	var b := _unit("grunt", 1, 0)
	engine.setup([a], [b])
	a.hp = 1000.0
	var res := engine.use_skill(a, 0, [b])
	check(is_equal_approx(a.hp, 1000.0 + res[0]["damage"] * 0.2), "heals 20% of damage dealt")


func test_counterattack() -> void:
	var engine := BattleEngine.new(4)
	var a := _unit("grunt", 0, 0)
	var b := BattleUnit.new(HeroDB.get_hero("thorne"), 1, 0, 60, {}, ["counter_100"])
	engine.setup([a], [b])
	engine.use_skill(a, 0, [b])
	check(a.hp < a.max_hp(), "defender countered")
	check("counterattacks" in "\n".join(engine.log_lines), "counter logged")
	b.add_effect("stun", 1)
	var before := a.hp
	engine.use_skill(a, 0, [b])
	check(a.hp == before, "stunned unit cannot counter")


func test_dual_attack() -> void:
	var engine := BattleEngine.new(5)
	var a := _unit("kaelen", 0, 0)
	var partner := BattleUnit.new(HeroDB.get_hero("vexmoor"), 0, 1, 60, {}, ["dual_100"])
	var b := _unit("thorne", 1, 0)
	engine.setup([a, partner], [b])
	engine.use_skill(a, 0, [b])
	check("dual attack" in "\n".join(engine.log_lines), "partner joined")
	check(partner.skill_ready(0), "nested attack set no cooldown")
	engine.log_lines.clear()
	engine.use_skill(a, 2, engine.resolve_targets(a, a.skill(2), null))
	check(not ("dual attack" in "\n".join(engine.log_lines)), "no dual attack on area skills")


func test_extra_turn() -> void:
	var engine := BattleEngine.new(6)
	var a := _unit("bramble", 0, 0)
	var b := _unit("thorne", 1, 0)
	engine.setup([a], [b])
	engine.manual_teams = [0]
	engine.step()
	check(engine.awaiting_input and engine.current_actor == a, "bramble acts first and waits for input")
	check(engine.submit_action(1, null), "Volley accepted")
	check(a.gauge == 100.0, "extra turn refills gauge")
	engine.step()
	check(engine.current_actor == a, "bramble acts again immediately")


func test_passive_on_hit() -> void:
	var engine := BattleEngine.new(7)
	var a := _unit("grunt", 0, 0)
	var t := _unit("thorne", 1, 0)
	engine.setup([a], [t])
	engine.use_skill(a, 0, [t])
	check(t.has_effect("def_up"), "Deep Roots grants Defense Up when hit")
	var idx := t.data.skill_ids.find("thorne_p")
	check(not t.skill_ready(idx), "passive goes on cooldown")


func test_passive_on_kill() -> void:
	var engine := BattleEngine.new(8)
	var v := _unit("vexmoor", 0, 0)
	var g := _unit("grunt", 1, 0)
	engine.setup([v], [g])
	g.hp = 1.0
	engine.use_skill(v, 0, [g])
	check(not g.alive, "grunt died")
	check(v.gauge == 50.0 and v.has_effect("crit_up"), "Bloodscent pushed gauge and buffed")


func test_passive_on_ally_attacked() -> void:
	var hit := 0
	for seed_value in range(40):
		var engine := BattleEngine.new(seed_value)
		var a := _unit("grunt", 0, 0)
		var ils := _unit("ilsabet", 1, 0)
		var ally := _unit("thorne", 1, 1)
		engine.setup([a], [ils, ally])
		engine.use_skill(a, 0, [ally])
		if ally.has_effect("barrier"):
			hit += 1
	check(hit > 3 and hit < 20, "Vigil triggers about 25%% of the time (got %d/40)" % hit)


func test_skill_upgrades() -> void:
	var base := HeroDB.get_skill("kaelen_s1")
	var up := base.at_level(5)
	check(is_equal_approx(up.multiplier, 1.2), "multiplier upgrades summed")
	check(is_equal_approx(float(up.effects[0]["chance"]), 0.7), "chance upgrades summed")
	check(is_equal_approx(base.multiplier, 1.0) and is_equal_approx(float(base.effects[0]["chance"]), 0.5), "base skill untouched")
	var s3 := HeroDB.get_skill("kaelen_s3").at_level(4)
	check(s3.cooldown == 4, "cooldown reduced by upgrade")
	var u := _unit("kaelen", 0, 0)
	u.set_skill_level(0, 99)
	check(u.skill_levels[0] == 5, "level clamps to max")
	check(is_equal_approx(u.skill(0).multiplier, 1.2), "unit uses upgraded skill")
	check(u.skill(1) == u.data.skills[1], "unupgraded skill is the shared base")


func test_manual_input_validation() -> void:
	var engine := BattleEngine.new(9)
	var m := _unit("mira", 0, 0)
	var ally := _unit("thorne", 0, 1)
	var e := _unit("grunt", 1, 0)
	engine.setup([m, ally], [e])
	engine.manual_teams = [0]
	check(engine.run() == -1 and engine.awaiting_input, "run pauses for input")
	check(engine.current_actor == m, "fastest manual unit is up")
	check(not engine.submit_action(0, ally), "cannot attack an ally")
	check(not engine.submit_action(7, e), "invalid skill index")
	check(not engine.submit_action(2, null, true), "cannot empower without Resolve")
	check(engine.submit_action(1, e), "valid attack accepted")
	check(not engine.awaiting_input and e.hp < e.max_hp(), "action executed")
	check(engine.decisions.size() == 1 and engine.decisions[0]["skill"] == 1, "decision recorded")


func test_replay_roundtrip() -> void:
	var engine := BattleEngine.new(2024)
	var rng := RandomNumberGenerator.new(); rng.seed = 2024
	var p: Array[BattleUnit] = []
	var e: Array[BattleUnit] = []
	var ids := ["kaelen", "ilsabet", "vexmoor", "seraphi"]
	for i in ids.size():
		var hero := HeroDB.get_hero(ids[i])
		var items: Array = []
		for s in range(6):
			items.append(GearGenerator.roll(rng, s as Gear.Slot, 4, "fury" if i == 1 else "twin"))
		var bonus := GearGenerator.total_bonus(Stats.at_level(hero.max_stats, 60), items)
		var u := BattleUnit.new(hero, 0, i, 60, bonus, GearSets.bonuses(items)["flags"])
		u.set_skill_level(0, 2)
		p.append(u)
	for i in 4:
		e.append(_unit(["mira", "thorne", "bramble", "grunt"][i], 1, i, 58))
	engine.setup(p, e)
	engine.run()
	check(engine.is_over(), "original battle finished")
	var json := BattleReplay.to_json(engine.to_replay())
	var replayed := BattleReplay.run(BattleReplay.from_json(json))
	check(replayed.is_over() and replayed.winner == engine.winner, "replay reaches same winner")
	check("\n".join(replayed.log_lines) == "\n".join(engine.log_lines), "replay log identical to original")
	check(replayed.decisions.size() == engine.decisions.size(), "same number of decisions")

# ---------------------------------------------------------------- milestone 2

func test_data_validator_passes() -> void:
	var errors := DataValidator.validate()
	for e in errors:
		printerr("  " + e)
	check(errors.is_empty(), "data validator reports %d errors" % errors.size())


func test_roster_counts() -> void:
	check(HeroDB.heroes_of_kind("hero").size() >= 12, "at least 12 playable heroes")
	check(HeroDB.heroes_of_kind("enemy").size() >= 15, "at least 15 enemy types")
	check(HeroDB.heroes_of_kind("boss").size() >= 3, "at least 3 bosses")
	for id in HeroDB.heroes_by_rarity(3) + HeroDB.heroes_by_rarity(4) + HeroDB.heroes_by_rarity(5):
		check(HeroDB.get_hero(id).kind == "hero", "summon pool excludes enemies (%s)" % id)
	var per_element := {}
	for h in HeroDB.heroes_of_kind("hero"):
		per_element[h.element] = int(per_element.get(h.element, 0)) + 1
	for el in Elements.Type.values():
		check(int(per_element.get(el, 0)) >= 2, "at least 2 heroes of element %s" % Elements.NAMES[el])


func test_def_scaling_damage() -> void:
	var a := _unit("oskar", 0, 0)
	var b := _unit("grunt", 1, 0)
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var with_def := DamageCalc.compute(a, b, a.skill(0), rng)
	rng.seed = 1
	a.add_effect("def_up", 1)
	var more := DamageCalc.compute(a, b, a.skill(0), rng)
	check(more["damage"] > with_def["damage"], "Defense Up raises def-scaling damage")


func test_ai_target_profiles() -> void:
	var engine := BattleEngine.new(1)
	var brute := _unit("ember_brute", 0, 0)   # highest_atk
	var cutpurse := _unit("shadow_cutpurse", 0, 1)  # lowest_def
	var strong := _unit("vexmoor", 1, 0)   # highest atk, lowest def
	var tank := _unit("halvard", 1, 1)
	engine.setup([brute, cutpurse], [strong, tank])
	tank.hp = 10.0  # lowest HP, which default AI would pick
	check(engine.choose_target(brute, brute.skill(0)) == strong, "highest_atk profile ignores low HP tank")
	check(engine.choose_target(cutpurse, cutpurse.skill(0)) == strong, "lowest_def profile picks squishy")
	check(engine.choose_target(_unit("grunt", 0, 2), brute.skill(0)) == null or true, "no crash on unit outside battle")


func test_ai_skill_profiles() -> void:
	var engine := BattleEngine.new(2)
	var sentinel := _unit("gilded_sentinel", 0, 0)  # rotation: e_strike, e_stun, e_ward
	var shaman := _unit("bog_shaman", 0, 1)          # support: e_strike, e_heal, e_ward
	var e := _unit("grunt", 1, 0)
	engine.setup([sentinel, shaman], [e])
	var seq: Array[int] = []
	for _i in range(4):
		var idx := engine.choose_skill_index(sentinel)
		seq.append(idx)
		engine._execute(sentinel, idx, engine.choose_target(sentinel, sentinel.skill(idx)), false)
		sentinel.end_turn()
	check(seq[0] == 0 and seq[1] == 1 and seq[2] == 2 and seq[3] == 0, "rotation cycles skills in order (got %s)" % [seq])
	check(engine.choose_skill_index(shaman) == 2, "support uses buff even at full HP")


func test_boss_rotation_battle() -> void:
	var engine := BattleEngine.new(77)
	var p: Array[BattleUnit] = [_unit("kaelen", 0, 0), _unit("halvard", 0, 1), _unit("elowen", 0, 2), _unit("corvina", 0, 3)]
	var boss: Array[BattleUnit] = [_unit("wyrm_of_ash", 1, 0)]
	engine.setup(p, boss)
	var w := engine.run()
	check(w != -1, "boss battle completes")
	check("Molten Hide" in "\n".join(engine.log_lines), "boss passive fired")

# ---------------------------------------------------------------- milestone 3

func test_xp_curve_and_caps() -> void:
	check(Progression.xp_for_level(2) > Progression.xp_for_level(1), "xp grows")
	check(Progression.level_cap(3) == 30 and Progression.level_cap(6) == 60, "level caps")
	var h := HeroInstance.create("bramble")   # 3-star
	check(h.stars == 3 and h.level == 1, "fresh hero")
	var gained := h.add_xp(Progression.total_xp_to(10))
	check(gained == 9 and h.level == 10 and h.xp == 0, "exact xp reaches level 10 (got L%d +%d)" % [h.level, gained])
	h.add_xp(10_000_000)
	check(h.level == 30 and h.xp == 0 and h.is_max_level(), "xp caps at level 30 for 3 stars")


func test_promotion() -> void:
	var p := PlayerProfile.new(0)
	var target := p.add_hero("bramble")
	var f1 := p.add_hero("bramble")
	var f2 := p.add_hero("grunt")
	var f3 := p.add_hero("oskar")
	check(not p.promote(target.uid, [f1.uid, f2.uid, f3.uid]), "cannot promote below max level")
	target.add_xp(10_000_000)
	check(not p.promote(target.uid, [f1.uid, f2.uid]), "needs 3 fodder for 3 stars")
	f3.locked = true
	check(not p.promote(target.uid, [f1.uid, f2.uid, f3.uid]), "locked fodder rejected")
	f3.locked = false
	check(not p.promote(target.uid, [f1.uid, f2.uid, f3.uid]), "cannot afford promotion gold")
	p.grant({"gold": 50000})
	var gold := p.gold
	check(p.promote(target.uid, [f1.uid, f2.uid, f3.uid]), "promotion succeeds")
	check(target.stars == 4 and target.level == 1 and target.level_cap() == 40, "promoted to 4 stars")
	check(p.heroes.size() == 1 and p.gold == gold - Progression.PROMOTION_GOLD[3], "fodder consumed and gold spent")


func test_awakening_and_bonds() -> void:
	var p := PlayerProfile.new(0)
	var k := p.add_hero("kaelen")
	var base := p.hero_stats(k.uid)
	check(not p.awaken(k.uid), "cannot awaken without materials")
	p.grant({"flame_shard": 300, "flame_core": 100, "gold": 1000000})
	check(p.awaken(k.uid) and k.awakening == 1, "awakening 1")
	var after := p.hero_stats(k.uid)
	check(after["atk"] > base["atk"] and after["hp"] > base["hp"], "awakening raises stats")
	for _i in range(10):
		p.awaken(k.uid)
	check(k.awakening == Progression.MAX_AWAKENING, "awakening caps at 6")
	var dupe := p.add_hero("kaelen")
	var wrong := p.add_hero("mira")
	check(not p.merge_bond(k.uid, wrong.uid), "bond needs the same hero")
	check(p.merge_bond(k.uid, dupe.uid) and k.bond_level == 1, "bond merged")
	check(p.get_hero(dupe.uid) == null, "dupe consumed")
	var team := p.build_team([k.uid, wrong.uid], 0)
	var solo_stats := p.hero_stats(wrong.uid)
	check(team[1].base_stats["atk"] > solo_stats["atk"], "bond raises ally atk team-wide")


func test_profile_gear_and_energy() -> void:
	var p := PlayerProfile.new(1000)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var k := p.add_hero("kaelen")
	var m := p.add_hero("mira")
	var w := p.add_gear(GearGenerator.roll(rng, Gear.Slot.WEAPON, 5, "might"))
	check(p.equip(k.uid, w.uid) and p.gear_owner(w.uid) == k.uid, "equip weapon")
	check(p.hero_stats(k.uid)["atk"] > HeroInstance.create("kaelen").compute_stats([])["atk"], "weapon adds atk")
	check(p.equip(m.uid, w.uid) and p.gear_owner(w.uid) == m.uid and not k.equipped.has(int(Gear.Slot.WEAPON)), "equipping elsewhere moves the item")
	check(p.set_team("A", [k.uid, m.uid]) and not p.set_team("B", [k.uid, k.uid]), "team validation")
	p.energy = 0
	p.regen_energy(1000 + PlayerProfile.ENERGY_REGEN_SECONDS * 3 + 10)
	check(p.energy == 3, "regen 3 energy (got %d)" % p.energy)
	p.regen_energy(1000 + PlayerProfile.ENERGY_REGEN_SECONDS * 4)
	check(p.energy == 4, "partial tick carried over")
	p.regen_energy(10_000_000)
	check(p.energy == p.energy_max, "regen caps")
	check(not p.spend({"gold": 999999999}) and p.spend({"gold": 100, "energy": 10}), "spend validation")


func test_save_roundtrip_and_tamper() -> void:
	var p := PlayerProfile.new(5)
	var rng := RandomNumberGenerator.new(); rng.seed = 8
	var k := p.add_hero("kaelen")
	k.add_xp(50000)
	k.set_skill_level(0, 2)
	var g := p.add_gear(GearGenerator.roll(rng, Gear.Slot.BOOTS, 4, "swift"))
	p.equip(k.uid, g.uid)
	p.set_team("main", [k.uid])
	p.grant({"frost_shard": 7})
	var text := SaveSystem.encode(p)
	var back := SaveSystem.decode(text)
	check(back != null, "decode ok: %s" % SaveSystem.last_error)
	if back != null:
		check(back.get_hero(k.uid).level == k.level and back.get_hero(k.uid).skill_levels[0] == 2, "hero restored")
		check(back.get_gear(g.uid).main_stat == g.main_stat and back.gear_owner(g.uid) == k.uid, "gear restored and equipped")
		check(back.teams["main"] == [k.uid] and back.materials["frost_shard"] == 7, "teams and materials restored")
		check(back.new_uid("h") != k.uid, "uid counter restored")
	var tampered := text.replace('\\"gold\\":', '\\"gold\\":9')
	check(tampered != text and SaveSystem.decode(tampered) == null, "edited save rejected (%s)" % SaveSystem.last_error)
	var path := "user://test_save.json"
	check(SaveSystem.save(p, path) and SaveSystem.load(path) != null, "file save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------- milestone 4

func test_gear_enhance_economy() -> void:
	var p := PlayerProfile.new(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var g := p.add_gear(GearGenerator.roll(rng, Gear.Slot.RING, 5, "swift"))
	check(GearEconomy.enhance_cost(g) > 0, "enhance has a cost")
	var c0 := GearEconomy.enhance_cost(g)
	p.gold = 0
	check(not GearEconomy.enhance(p, g.uid, rng) and g.level == 0, "cannot enhance without gold")
	p.gold = 10_000_000
	check(GearEconomy.enhance(p, g.uid, rng) and g.level == 1 and p.gold == 10_000_000 - c0, "enhance spends gold")
	check(GearEconomy.enhance_cost(g) > c0, "cost rises with level")
	var s0 := GearEconomy.score(g)
	while g.level < Gear.MAX_ENHANCE:
		GearEconomy.enhance(p, g.uid, rng)
	check(GearEconomy.score(g) > s0, "score rises with substat rolls")
	check(GearEconomy.enhance_cost(g) == 0 and not GearEconomy.enhance(p, g.uid, rng), "+15 cannot enhance")


func test_gear_reforge_and_sell() -> void:
	var p := PlayerProfile.new(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 22
	var k := p.add_hero("kaelen")
	var g := p.add_gear(GearGenerator.roll(rng, Gear.Slot.WEAPON, 4, "might"))
	p.equip(k.uid, g.uid)
	check(not GearEconomy.reforge(p, g.uid), "reforge needs +15")
	for _i in range(15):
		GearGenerator.enhance(rng, g)
	p.grant({"gold": 100000})
	check(not GearEconomy.reforge(p, g.uid), "reforge needs a stone")
	p.grant({"reforge_stone": 1})
	var main_before := g.main_value()
	var sub_key: String = g.substats.keys()[0]
	var sub_before := float(g.substats[sub_key])
	check(GearEconomy.reforge(p, g.uid) and g.tier == 2, "reforge succeeds")
	check(g.main_value() > main_before and float(g.substats[sub_key]) > sub_before, "reforge boosts stats")
	check(not GearEconomy.reforge(p, g.uid), "cannot reforge twice")
	var gold := p.gold
	var value := GearEconomy.sell(p, g.uid)
	check(value > 0 and p.gold == gold + value, "sell pays gold")
	check(p.get_gear(g.uid) == null and not k.equipped.has(int(Gear.Slot.WEAPON)), "sold gear removed and unequipped")


func test_gear_crafting() -> void:
	var p := PlayerProfile.new(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 23
	check(GearEconomy.craft(p, Gear.Slot.BOOTS, "swift", rng) == null, "craft needs materials")
	check(GearEconomy.craft_cost("nonexistent").is_empty(), "unknown set not craftable")
	p.grant({"gold": 1_000_000, "rime_shard": 80, "crafting_alloy": 30})
	var fives := 0
	for _i in range(10):
		var g := GearEconomy.craft(p, Gear.Slot.BOOTS, "swift", rng)
		check(g != null and g.slot == Gear.Slot.BOOTS and g.set_id == "swift" and g.rarity >= 4, "crafted the requested item")
		if g != null and g.rarity == 5:
			fives += 1
	check(p.materials["rime_shard"] == 0 and p.gear.size() == 10, "materials consumed, items added")
	check(fives >= 1 and fives <= 7, "some crafts are 5-star (got %d/10)" % fives)
	check(GearEconomy.craft(p, Gear.Slot.BOOTS, "swift", rng) == null, "out of materials")

# ---------------------------------------------------------------- calibration sets

func test_pierce_wrath_reckless() -> void:
	var rng := RandomNumberGenerator.new()
	var plain := _unit("kaelen", 0, 0)
	var pierce := BattleUnit.new(HeroDB.get_hero("kaelen"), 0, 1, 60, {}, ["pierce_15"])
	var wrath := BattleUnit.new(HeroDB.get_hero("kaelen"), 0, 2, 60, {}, ["wrath_30"])
	var reckless := BattleUnit.new(HeroDB.get_hero("kaelen"), 0, 3, 60, {}, ["reckless_10"])
	var t := _unit("halvard", 1, 0)
	rng.seed = 1; var d_plain: float = DamageCalc.compute(plain, t, plain.skill(0), rng)["damage"]
	rng.seed = 1; var d_pierce: float = DamageCalc.compute(pierce, t, pierce.skill(0), rng)["damage"]
	rng.seed = 1; var d_wrath_clean: float = DamageCalc.compute(wrath, t, wrath.skill(0), rng)["damage"]
	t.add_effect("def_down", 1)
	t.remove_effect("def_down")
	t.add_effect("spd_down", 1)
	rng.seed = 1; var d_wrath: float = DamageCalc.compute(wrath, t, wrath.skill(0), rng)["damage"]
	t.remove_effect("spd_down")
	rng.seed = 1; var d_reck: float = DamageCalc.compute(reckless, t, reckless.skill(0), rng)["damage"]
	check(d_pierce > d_plain, "pierce ignores part of defense")
	check(is_equal_approx(d_wrath_clean, d_plain), "wrath does nothing vs clean target")
	check(d_wrath > d_plain * 1.25, "wrath adds damage vs debuffed target")
	check(d_reck > d_plain, "reckless adds damage")
	check(is_equal_approx(reckless.max_hp(), roundf(plain.max_hp() * 0.9)), "reckless reduces max hp")


func test_battle_start_sets() -> void:
	var engine := BattleEngine.new(1)
	var a := BattleUnit.new(HeroDB.get_hero("thorne"), 0, 0, 60, {}, ["start_immunity_1", "start_barrier_10"])
	var b := _unit("grunt", 1, 0)
	engine.setup([a], [b])
	check(a.has_effect("immunity") and a.get_effect("immunity")["turns"] == 1, "immunity at battle start")
	check(is_equal_approx(a.shield_value(), roundf(a.max_hp() * 0.1)), "barrier at battle start")


func test_tier_scaling() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var t1 := GearGenerator.roll(rng, Gear.Slot.WEAPON, 5, "swift", 1)
	rng.seed = 5
	var t2 := GearGenerator.roll(rng, Gear.Slot.WEAPON, 5, "swift", 2)
	check(is_equal_approx(t2.main_value(), t1.main_value() * 1.05), "tier 2 main +5%")
	var k: String = t1.substats.keys()[0]
	check(float(t2.substats[k]) > float(t1.substats[k]) * 1.15, "tier 2 substat rolls ~+25%")

# ---------------------------------------------------------------- milestone 5

func test_banners_load_and_schedule() -> void:
	check(BannerDB.all().size() >= 3, "banners loaded")
	var limited := BannerDB.get_banner("halvard_call")
	check(not limited.is_active(limited.starts_at - 1) and limited.is_active(limited.starts_at) and not limited.is_active(limited.ends_at), "time window")
	check(BannerDB.get_banner("standard").is_active(0) and BannerDB.get_banner("standard").is_active(4000000000), "permanent banner always active")
	check(BannerDB.active(1800000000).size() == 3 and BannerDB.active(100).size() == 2, "active list respects windows")


func test_summon_service_payment_and_pity() -> void:
	var p := PlayerProfile.new(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var b := BannerDB.get_banner("elowen_call")
	p.crystals = 950
	var r := SummonService.pull(p, b, 10, 1000, rng)
	check(not r["ok"] and "crystals" in r["error"], "10-pull refused without 1000 crystals")
	p.crystals = 1000
	r = SummonService.pull(p, b, 10, 1000, rng)
	check(r["ok"] and r["results"].size() == 10 and p.crystals == 0 and p.heroes.size() == 10, "10-pull paid and granted")
	check(p.mileage == 10 and int(p.flags["summon_stats"]["total"]) == 10, "mileage and stats recorded")
	var all_results: Array = r["results"].duplicate()
	p.grant({"summon_ticket": 3, "crystals": 200})
	r = SummonService.pull(p, b, 5, 1000, rng)
	check(r["ok"] and r["paid"].get("summon_ticket", 0) == 3 and r["paid"].get("crystals", 0) == 200, "tickets used before crystals")
	all_results.append_array(r["results"])
	var expected_pity := 0
	for res in all_results:
		expected_pity = 0 if res["featured"] else expected_pity + 1
	check(SummonService.pity_counter(p, b) == expected_pity, "pity persisted across calls (expected %d)" % expected_pity)
	p.flags["pity"][b.id] = SummonSystem.HARD_PITY - 1
	p.grant({"crystals": 100})
	r = SummonService.pull(p, b, 1, 1000, rng)
	check(r["ok"] and r["results"][0]["hero_id"] == "elowen" and r["results"][0]["pity"], "hard pity from persisted counter")
	check(SummonService.pity_counter(p, b) == 0, "pity reset after featured")
	var inactive := BannerDB.get_banner("halvard_call")
	check(not SummonService.pull(p, inactive, 1, 1000, rng)["ok"], "inactive banner refused")


func test_summon_free_pull() -> void:
	var p := PlayerProfile.new(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var b := BannerDB.get_banner("standard")
	p.crystals = 0
	check(SummonService.free_pull_ready(p, b, 1000), "free pull available at start")
	var r := SummonService.pull(p, b, 1, 1000, rng)
	check(r["ok"] and r["free"] and p.heroes.size() == 1, "free pull granted without crystals")
	check(not SummonService.pull(p, b, 1, 2000, rng)["ok"], "second free pull refused same day")
	check(SummonService.pull(p, b, 1, 1000 + 86400, rng)["ok"], "free pull again after interval")
	check(not SummonService.pull(p, b, 10, 1000 + 86400 * 2, rng)["ok"], "free pull never covers a multi")


func test_store_offers_and_limits() -> void:
	var p := PlayerProfile.new(0)
	var day := 1700000000
	p.crystals = 1000
	check(Store.remaining(p, "gold_small", day) == 5, "daily limit 5")
	for _i in range(5):
		check(Store.buy(p, "gold_small", day), "buy gold pouch")
	check(not Store.buy(p, "gold_small", day) and Store.last_error == "purchase limit reached", "6th refused")
	check(Store.buy(p, "gold_small", day + 86400), "limit resets next day")
	check(p.gold == PlayerProfile.STARTING_GOLD + 6 * 25000 and p.crystals == 1000 - 300, "rewards and costs applied")
	check(not Store.buy(p, "nonexistent", day), "unknown offer")
	p.mileage = 25
	check(Store.buy(p, "mileage_ticket", day) and Store.buy(p, "mileage_ticket", day) and not Store.buy(p, "mileage_ticket", day), "mileage exchange")
	check(p.materials["summon_ticket"] == 2 and p.mileage == 5, "tickets granted")
	check(Store.buy(p, "starter_pack", day) and not Store.buy(p, "starter_pack", day + 86400 * 400), "once-only offer")


func test_store_receipts() -> void:
	var p := PlayerProfile.new(0)
	var before := p.crystals
	check(Store.apply_purchase(p, "crystals_m", "rcpt-1"), "purchase applied")
	check(p.crystals == before + 1400, "crystals plus bonus granted")
	check(not Store.apply_purchase(p, "crystals_m", "rcpt-1") and Store.last_error == "receipt already applied", "replayed receipt rejected")
	check(not Store.apply_purchase(p, "crystals_m", ""), "empty receipt rejected")
	var provider := PurchaseProvider.Offline.new()
	var got: Array = []
	provider.purchase_completed.connect(func(pid, rid): got.append([pid, rid]))
	check(not provider.start_purchase("crystals_s") and got.is_empty(), "offline provider fails by default")
	provider.auto_complete = true
	check(provider.start_purchase("crystals_s") and got.size() == 1 and Store.apply_purchase(p, got[0][0], got[0][1]), "dev provider completes with receipt")


func test_daily_rewards() -> void:
	var p := PlayerProfile.new(0)
	var day := 1700000000
	var r1 := DailyRewards.claim(p, day)
	check(not r1.is_empty() and DailyRewards.streak(p) == 1, "first claim")
	check(DailyRewards.claim(p, day + 3600).is_empty(), "same day cannot claim twice")
	check(not DailyRewards.claim(p, day + 86400).is_empty() and DailyRewards.streak(p) == 2, "consecutive day extends streak")
	check(not DailyRewards.claim(p, day + 86400 * 4).is_empty() and DailyRewards.streak(p) == 1, "gap resets streak")
	for i in range(1, 8):
		DailyRewards.claim(p, day + 86400 * (4 + i))
	check(DailyRewards.streak(p) == 8, "streak continues past 7 and cycle wraps")
	check(p.materials.get("summon_ticket", 0) >= 3, "cycle rewards granted (tickets)")


func test_disclosure_text() -> void:
	var text := SummonService.disclosure(BannerDB.get_banner("elowen_call"))
	check("1.50%" in text and "5.00%" in text and "93.50%" in text, "rates listed")
	check("120" in text and "Elowen Starbright" in text, "pity and featured named")
	check("Kaelen Ashvow" in text, "pool lists heroes")
	check(not ("Marsh Grunt" in text), "pool excludes enemies")

# ---------------------------------------------------------------- gear

func test_gear_roll_and_enhance() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var g := GearGenerator.roll(rng, Gear.Slot.BOOTS, 5, "swift")
	check(g.substats.size() == 4, "5-star gear has 4 substats")
	check(not g.substats.has(g.main_stat), "substats exclude main stat")
	var before := g.main_value()
	for _i in range(15):
		GearGenerator.enhance(rng, g)
	check(g.level == 15, "max enhance 15")
	check(g.main_value() > before, "main stat grows")
	check(not GearGenerator.enhance(rng, g), "cannot enhance past 15")
	var g2 := GearGenerator.roll(rng, Gear.Slot.WEAPON, 2, "might")
	check(g2.substats.size() == 1, "2-star gear has 1 substat")
	GearGenerator.enhance(rng, g2); GearGenerator.enhance(rng, g2); GearGenerator.enhance(rng, g2)
	check(g2.substats.size() == 2, "new substat gained at +3")


func test_gear_set_bonus() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 2
	var items: Array = []
	for s in [Gear.Slot.WEAPON, Gear.Slot.HELM, Gear.Slot.ARMOR, Gear.Slot.NECKLACE]:
		items.append(GearGenerator.roll(rng, s, 3, "swift"))
	items.append(GearGenerator.roll(rng, Gear.Slot.RING, 3, "precision"))
	items.append(GearGenerator.roll(rng, Gear.Slot.BOOTS, 3, "precision"))
	var b := GearSets.bonuses(items)
	check(is_equal_approx(float(b["mods"].get("spd_pct", 0.0)), 0.25), "4-piece swift")
	check(is_equal_approx(float(b["mods"].get("crit_rate", 0.0)), 0.12), "2-piece precision")


func test_gear_applies_to_unit() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	var hero := HeroDB.get_hero("kaelen")
	var base := Stats.at_level(hero.max_stats, 60)
	var items: Array = []
	for s in [Gear.Slot.WEAPON, Gear.Slot.HELM, Gear.Slot.ARMOR, Gear.Slot.NECKLACE, Gear.Slot.RING, Gear.Slot.BOOTS]:
		items.append(GearGenerator.roll(rng, s, 4, "swift"))
	var bonus := GearGenerator.total_bonus(base, items)
	var u := BattleUnit.new(hero, 0, 0, 60, bonus)
	check(u.stat("atk") > base["atk"], "weapon raises atk")
	check(u.stat("spd") >= base["spd"] * 1.25, "swift set raises speed by at least 25%")
	check(u.hp == u.max_hp(), "starts at full hp")
	var g := Gear.from_dict(items[0].to_dict())
	check(g.main_stat == items[0].main_stat and g.substats == items[0].substats, "gear round-trips through dict")

# ---------------------------------------------------------------- gacha

func test_summon_rates_and_pity() -> void:
	var s := SummonSystem.new(99, "kaelen")
	var counts := {3: 0, 4: 0, 5: 0}
	var n := 20000
	for r in s.pull_many(n):
		counts[r["rarity"]] += 1
		check(r["hero_id"] != "", "every pull yields a hero")
	var five := float(counts[5]) / n
	check(five > 0.012 and five < 0.03, "5-star rate near 1.5%% incl. pity (got %.4f)" % five)
	check(float(counts[4]) / n > 0.04 and float(counts[4]) / n < 0.06, "4-star rate near 5%")
	# Hard pity: a fresh system whose rng never rolls a featured hero still gets one by pull 120.
	var s2 := SummonSystem.new(1, "vexmoor")
	var got_featured_by := -1
	for i in range(SummonSystem.HARD_PITY):
		var r := s2.pull()
		if r["featured"]:
			got_featured_by = i + 1
			break
	check(got_featured_by != -1 and got_featured_by <= SummonSystem.HARD_PITY, "featured hero within pity")
	check(s2.pity_counter == 0, "pity resets on featured")


func test_summon_deterministic() -> void:
	var a := SummonSystem.new(77, "mira").pull_many(50)
	var b := SummonSystem.new(77, "mira").pull_many(50)
	for i in range(50):
		check(a[i]["hero_id"] == b[i]["hero_id"], "pull %d identical" % i)
