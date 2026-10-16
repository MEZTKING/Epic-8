class_name StageService
extends RefCounted
## Starts and completes stages against a PlayerProfile: unlock rules, energy,
## enemy scaling, star grading, rewards, gear drops and progress flags.

const MAX_STARS := 3

static var last_error: String = ""


static func progress(profile: PlayerProfile, stage_id: String) -> Dictionary:
	return profile.flags.get("stages", {}).get(stage_id, {})


static func is_cleared(profile: PlayerProfile, stage_id: String) -> bool:
	return int(progress(profile, stage_id).get("clears", 0)) > 0


static func best_stars(profile: PlayerProfile, stage_id: String) -> int:
	return int(progress(profile, stage_id).get("stars", 0))


static func weekday(now_unix: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(now_unix)["weekday"])


static func is_unlocked(profile: PlayerProfile, stage: Stage) -> bool:
	return stage.requires == "" or is_cleared(profile, stage.requires)


static func is_available(profile: PlayerProfile, stage: Stage, now_unix: int) -> bool:
	if not is_unlocked(profile, stage):
		return false
	if not stage.is_open_on(weekday(now_unix)):
		return false
	if stage.once and is_cleared(profile, stage.id):
		return false
	return true


## Enemy units scaled to the stage level. Bosses keep their big HP pools.
static func enemies_for(stage: Stage) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for i in stage.enemies.size():
		var data := HeroDB.get_hero(stage.enemies[i])
		if data == null:
			continue
		out.append(BattleUnit.new(data, 1, i, stage.level))
	return out


## Spends energy and returns {"ok", "error", "enemy": Array[BattleUnit], "seed": int}.
static func start(profile: PlayerProfile, stage: Stage, now_unix: int, rng: RandomNumberGenerator = null) -> Dictionary:
	last_error = ""
	var out := {"ok": false, "error": "", "enemy": [], "seed": 0}
	if stage == null:
		out["error"] = "no such stage"
	elif not is_unlocked(profile, stage):
		out["error"] = "locked: clear %s first" % stage.requires
	elif not stage.is_open_on(weekday(now_unix)):
		out["error"] = "not open today"
	elif stage.once and is_cleared(profile, stage.id):
		out["error"] = "already cleared"
	else:
		profile.regen_energy(now_unix)
		if not profile.spend({"energy": stage.energy}):
			out["error"] = "not enough energy"
	if out["error"] != "":
		last_error = out["error"]
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	out["ok"] = true
	out["enemy"] = enemies_for(stage)
	out["seed"] = rng.randi()
	return out


## Stars: 1 for the win, +1 with no ally defeated, +1 within the turn limit.
static func stars_for(stage: Stage, result: Dictionary, team_size: int) -> int:
	if int(result.get("winner", -1)) != 0:
		return 0
	var stars := 1
	if int(result.get("survivors", 0)) >= team_size:
		stars += 1
	if int(result.get("turns", 999)) <= stage.turn_limit_for_star:
		stars += 1
	return stars


## Applies the outcome. `result` comes from the battle scene:
## {"winner", "turns", "survivors", "team_uids": [...]}.
## Returns {"won", "stars", "first_clear", "gold", "xp", "materials", "gear", "bonus"}.
static func complete(profile: PlayerProfile, stage: Stage, result: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var team: Array = result.get("team_uids", [])
	var out := {"won": false, "stars": 0, "first_clear": false, "gold": 0, "xp": 0, "materials": {}, "gear": null, "bonus": {}}
	if int(result.get("winner", -1)) != 0:
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	out["won"] = true
	out["stars"] = stars_for(stage, result, maxi(team.size(), 1))
	var first := not is_cleared(profile, stage.id)
	out["first_clear"] = first

	var gold := int(stage.rewards.get("gold", 0))
	var xp := int(stage.rewards.get("xp", 0))
	var mats: Dictionary = stage.material_rewards().duplicate()
	profile.grant({"gold": gold})
	for k in mats.keys():
		profile.grant({k: int(mats[k])})
	for uid in team:
		profile.add_xp(str(uid), xp)
	out["gold"] = gold
	out["xp"] = xp
	out["materials"] = mats
	if first and not stage.first_clear.is_empty():
		profile.grant(stage.first_clear)
		out["bonus"] = stage.first_clear.duplicate()

	if not stage.gear_drop.is_empty() and rng.randf() < float(stage.gear_drop.get("chance", 0.0)):
		out["gear"] = _roll_drop(profile, stage, rng)

	var all: Dictionary = profile.flags.get("stages", {})
	var rec: Dictionary = all.get(stage.id, {"clears": 0, "stars": 0})
	rec["clears"] = int(rec["clears"]) + 1
	rec["stars"] = maxi(int(rec["stars"]), int(out["stars"]))
	all[stage.id] = rec
	profile.flags["stages"] = all
	return out


static func _roll_drop(profile: PlayerProfile, stage: Stage, rng: RandomNumberGenerator) -> Gear:
	var weights: Dictionary = stage.gear_drop.get("rarity_weights", {"3": 60, "4": 35, "5": 5})
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var roll := rng.randf() * total
	var rarity := 3
	for k in ["3", "4", "5"]:
		roll -= float(weights.get(k, 0))
		if roll <= 0.0:
			rarity = int(k)
			break
	var material := _boss_material(stage.boss)
	var sets: Array = GearEconomy.CRAFTABLE_SETS.get(material, []).duplicate()
	if sets.is_empty():
		sets = GearSets.SETS.keys()
	var set_id: String = sets[rng.randi_range(0, sets.size() - 1)]
	var slot := rng.randi_range(0, 5) as Gear.Slot
	return profile.add_gear(GearGenerator.roll(rng, slot, rarity, set_id, int(stage.gear_drop.get("tier", 1))))


static func _boss_material(boss_id: String) -> String:
	match boss_id:
		"wyrm_of_ash": return "ash_scale"
		"glacial_matriarch": return "rime_shard"
		"hollow_king": return "hollow_bone"
	return ""


## Stage list for a menu: each entry has the stage plus availability and progress.
static func listing(profile: PlayerProfile, type: String, now_unix: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in StageDB.of_type(type):
		out.append({
			"stage": s, "unlocked": is_unlocked(profile, s), "available": is_available(profile, s, now_unix),
			"cleared": is_cleared(profile, s.id), "stars": best_stars(profile, s.id),
		})
	return out
