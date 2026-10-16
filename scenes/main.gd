extends Control
## Milestone 0 demo: text-mode auto battle and summon simulator.
## Everything here is throwaway; the real battle scene arrives in Milestone 6.

@onready var log_box: RichTextLabel = %Log
@onready var seed_spin: SpinBox = %Seed


func _ready() -> void:
	HeroDB.load_all()
	%BattleButton.pressed.connect(_on_battle)
	%SummonButton.pressed.connect(_on_summon)
	%RosterButton.pressed.connect(_on_roster)
	%ProfileButton.pressed.connect(_on_profile)
	%OpenBattleButton.pressed.connect(_on_open_battle)
	_on_roster()


func _on_roster() -> void:
	log_box.clear()
	log_box.append_text("[b]Roster[/b]\n")
	for h in HeroDB.all_heroes():
		var s := Stats.at_level(h.max_stats, 60)
		log_box.append_text("%s★ %s — %s %s | ATK %d DEF %d HP %d SPD %d\n" % [h.rarity, h.name, h.element_name(), h.role, s["atk"], s["def"], s["hp"], s["spd"]])
		for sk in h.skills:
			log_box.append_text("    • %s%s: %s\n" % [sk.name, " (CD %d)" % sk.cooldown if sk.cooldown > 0 else "", sk.description])


func _on_battle() -> void:
	log_box.clear()
	var engine := BattleEngine.new(int(seed_spin.value))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_spin.value)
	var p: Array[BattleUnit] = []
	var e: Array[BattleUnit] = []
	var ids := ["kaelen", "mira", "ilsabet", "seraphi"]
	for i in ids.size():
		p.append(_geared_unit(rng, ids[i], 0, i, 60, 4))
	var eids := ["vexmoor", "bramble", "grunt", "grunt"]
	for i in eids.size():
		e.append(_geared_unit(rng, eids[i], 1, i, 55, 3))
	engine.setup(p, e)
	engine.run()
	log_box.append_text("[b]Auto battle (seed %d)[/b]\n" % int(seed_spin.value))
	for line in engine.log_lines:
		log_box.append_text(line + "\n")


func _geared_unit(rng: RandomNumberGenerator, id: String, team: int, slot: int, level: int, gear_rarity: int) -> BattleUnit:
	var hero := HeroDB.get_hero(id)
	var base := Stats.at_level(hero.max_stats, level)
	var items: Array = []
	var set_id: String = ["swift", "might", "fury", "siphon"][slot % 4]
	for s in range(6):
		var g := GearGenerator.roll(rng, s as Gear.Slot, gear_rarity, set_id)
		for _i in range(9):
			GearGenerator.enhance(rng, g)
		items.append(g)
	return BattleUnit.new(hero, team, slot, level, GearGenerator.total_bonus(base, items), GearSets.bonuses(items)["flags"])


func _on_summon() -> void:
	log_box.clear()
	var s := SummonSystem.new(int(seed_spin.value), "kaelen")
	log_box.append_text("[b]10x summon (seed %d) — featured: Kaelen Ashvow[/b]\n" % int(seed_spin.value))
	for r in s.pull_many(10):
		var h := HeroDB.get_hero(r["hero_id"])
		var tag := ""
		if r["pity"]:
			tag = " [PITY]"
		elif r["featured"]:
			tag = " [FEATURED]"
		log_box.append_text("%s★ %s%s\n" % [r["rarity"], h.name if h else r["hero_id"], tag])
	log_box.append_text("\nRates: ")
	for row in SummonSystem.rate_table():
		log_box.append_text("%d★ %.2f%%  " % [row["rarity"], row["rate"] * 100.0])
	log_box.append_text("| hard pity at %d\n" % SummonSystem.HARD_PITY)


func _on_profile() -> void:
	log_box.clear()
	var now := int(Time.get_unix_time_from_system())
	var p := PlayerProfile.new(now)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_spin.value)
	log_box.append_text("[b]Profile demo[/b]\n")
	var summons := SummonSystem.new(int(seed_spin.value), "elowen")
	for r in summons.pull_many(10):
		p.add_hero(r["hero_id"])
	p.crystals -= 10 * SummonSystem.COST_PER_PULL
	var first: HeroInstance = p.heroes.values()[0]
	first.add_xp(Progression.total_xp_to(first.level_cap()))
	for slot in range(6):
		var g := p.add_gear(GearGenerator.roll(rng, slot as Gear.Slot, 4, "swift"))
		for _i in range(6):
			GearGenerator.enhance(rng, g)
		p.equip(first.uid, g.uid)
	p.grant({"%s_shard" % first.data().element_name().to_lower(): 30, "gold": 20000})
	p.awaken(first.uid)
	var st := p.hero_stats(first.uid)
	log_box.append_text("Owned heroes: %d | gold %d | crystals %d\n" % [p.heroes.size(), p.gold, p.crystals])
	log_box.append_text("%s %d★ L%d awakening %d | ATK %d DEF %d HP %d SPD %d\n" % [first.data().name, first.stars, first.level, first.awakening, st["atk"], st["def"], st["hp"], st["spd"]])
	var ok := SaveSystem.save(p)
	var back := SaveSystem.load()
	log_box.append_text("Saved to %s: %s | reloaded: %s\n" % [ProjectSettings.globalize_path(SaveSystem.SAVE_PATH), ok, back != null])
	if back != null:
		var unit := back.build_team([first.uid], 0)[0]
		log_box.append_text("Rebuilt battle unit: %s HP %d flags %s\n" % [unit.display_name(), unit.max_hp(), unit.flags])


func _on_open_battle() -> void:
	var pb := DemoTeams.default_battle(int(seed_spin.value))
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.start_battle(pb["player"], pb["enemy"], int(seed_spin.value), false)
	else:
		get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
