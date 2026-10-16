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
	var targets := engine.choose_targets(enemy, enemy.data.skills[0])
	check(targets.size() == 1 and targets[0] == tank, "provoked unit attacks provoker")


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
