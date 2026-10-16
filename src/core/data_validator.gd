class_name DataValidator
extends RefCounted
## Validates data/heroes.json and data/skills.json. Returns a list of error
## strings; empty means valid. Run headless via tests/validate_data.gd and in CI.

const VALID_TARGETS := ["enemy", "all_enemies", "self", "ally", "all_allies"]
const VALID_EFFECT_TARGETS := ["hit", "self", "self_before", "all_allies", "all_enemies", "highest_atk_enemy", "victim", "lowest_hp_ally"]
const VALID_TRIGGERS := ["on_turn_start", "on_hit", "on_ally_attacked", "on_kill"]
const VALID_ROLES := ["warrior", "knight", "mage", "ranger", "healer", "assassin"]
const VALID_KINDS := ["hero", "enemy", "boss"]
const VALID_AI_SKILL := ["strongest", "rotation", "random", "support"]
const VALID_AI_TARGET := ["lowest_hp", "highest_atk", "lowest_def", "random"]
const VALID_UPGRADE_KEYS := ["multiplier", "chance", "cooldown", "heal_percent", "gauge_push"]

const STAT_RANGES := {
	"atk": [300, 2000], "def": [200, 1200], "hp": [2000, 50000], "spd": [60, 160],
	"crit_rate": [0.0, 1.0], "crit_dmg": [1.0, 3.0], "eff": [0.0, 1.0], "res": [0.0, 1.0],
}


static func validate() -> Array[String]:
	var errors: Array[String] = []
	HeroDB.load_all(true)
	var skills := HeroDB.all_skills()
	var heroes := HeroDB.all_heroes()
	if heroes.is_empty():
		errors.append("no heroes loaded")
	if skills.is_empty():
		errors.append("no skills loaded")
	for s in skills:
		_validate_skill(s, errors)
	var used: Dictionary = {}
	for h in heroes:
		_validate_hero(h, errors)
		for sid in h.skill_ids:
			used[sid] = true
	for s in skills:
		if not used.has(s.id):
			errors.append("skill %s is not used by any hero" % s.id)
	BannerDB.load_all(true)
	for b in BannerDB.all():
		if b.type == "featured" and HeroDB.get_hero(b.featured_id) == null:
			errors.append("banner %s: featured hero '%s' does not exist" % [b.id, b.featured_id])
		if b.type == "featured" and (b.rate_up <= 0.0 or b.rate_up > 1.0):
			errors.append("banner %s: rate_up out of range" % b.id)
		if b.cost.is_empty():
			errors.append("banner %s: no cost" % b.id)
		if b.ends_at > 0 and b.ends_at <= b.starts_at:
			errors.append("banner %s: ends before it starts" % b.id)
	_validate_stages(errors)
	_validate_dialogues(errors)
	return errors


static func _validate_stages(errors: Array[String]) -> void:
	StageDB.load_all(true)
	var stages := StageDB.all()
	if stages.is_empty():
		errors.append("no stages loaded")
	var ids := {}
	for s in stages:
		var tag := "stage %s" % s.id
		if ids.has(s.id):
			errors.append("%s: duplicate id" % tag)
		ids[s.id] = true
		if not s.type in ["adventure", "hunt", "tower", "daily"]:
			errors.append("%s: bad type %s" % [tag, s.type])
		if s.enemies.is_empty() or s.enemies.size() > 4:
			errors.append("%s: needs 1..4 enemies" % tag)
		for e in s.enemies:
			var h := HeroDB.get_hero(e)
			if h == null:
				errors.append("%s: unknown enemy %s" % [tag, e])
			elif h.kind == "hero":
				errors.append("%s: playable hero %s used as enemy" % [tag, e])
		if s.level < 1 or s.level > Stats.MAX_LEVEL:
			errors.append("%s: level out of range" % tag)
		if s.energy < 0 or s.energy > 50:
			errors.append("%s: energy out of range" % tag)
		if s.boss != "" and (HeroDB.get_hero(s.boss) == null or HeroDB.get_hero(s.boss).kind != "boss"):
			errors.append("%s: boss %s is not a boss unit" % [tag, s.boss])
		if not s.gear_drop.is_empty():
			var c := float(s.gear_drop.get("chance", -1.0))
			if c < 0.0 or c > 1.0:
				errors.append("%s: gear drop chance out of range" % tag)
		for w in s.weekdays:
			if w < 0 or w > 6:
				errors.append("%s: bad weekday %d" % [tag, w])
	for s in stages:
		if s.requires != "" and not ids.has(s.requires):
			errors.append("stage %s: requires unknown stage %s" % [s.id, s.requires])
	for c in range(1, 11):
		if StageDB.chapter(c).size() != 10:
			errors.append("chapter %d does not have 10 stages" % c)


static func _validate_dialogues(errors: Array[String]) -> void:
	Dialogue.load_all(true)
	for d in Dialogue.all():
		if d.lines.is_empty():
			errors.append("dialogue %s: no lines" % d.id)
		if d.after_stage != "" and StageDB.get_stage(d.after_stage) == null:
			errors.append("dialogue %s: after_stage %s does not exist" % [d.id, d.after_stage])
		for l in d.lines:
			if l["text"] == "":
				errors.append("dialogue %s: empty line" % d.id)
			if l["speaker"] != "Narrator":
				var found := false
				for h in HeroDB.all_heroes():
					if h.name == l["speaker"]:
						found = true
				if not found:
					errors.append("dialogue %s: unknown speaker %s" % [d.id, l["speaker"]])


static func _validate_skill(s: SkillData, errors: Array[String]) -> void:
	var tag := "skill %s" % s.id
	if s.id == "" or s.name == "":
		errors.append("%s: missing id or name" % tag)
	if s.description == "":
		errors.append("%s: missing description" % tag)
	if s.passive:
		if not s.trigger in VALID_TRIGGERS:
			errors.append("%s: bad passive trigger '%s'" % [tag, s.trigger])
		if s.chance <= 0.0 or s.chance > 1.0:
			errors.append("%s: passive chance out of range" % tag)
	else:
		if not s.target in VALID_TARGETS:
			errors.append("%s: bad target '%s'" % [tag, s.target])
		if s.multiplier < 0.0 or s.multiplier > 4.0:
			errors.append("%s: multiplier %.2f out of range" % [tag, s.multiplier])
		if s.cooldown < 0 or s.cooldown > 8:
			errors.append("%s: cooldown out of range" % tag)
		if s.resolve_cost > 0 and s.cooldown == 0:
			errors.append("%s: Resolve skills must have a cooldown" % tag)
	for ef in s.effects:
		if not ef is Dictionary:
			errors.append("%s: effect entry is not a dictionary" % tag)
			continue
		var where: String = ef.get("target", "hit")
		if not where in VALID_EFFECT_TARGETS:
			errors.append("%s: bad effect target '%s'" % [tag, where])
		if where == "victim" and s.trigger != "on_ally_attacked":
			errors.append("%s: 'victim' target only valid for on_ally_attacked passives" % tag)
		var chance := float(ef.get("chance", 1.0))
		if chance <= 0.0 or chance > 1.0:
			errors.append("%s: effect chance out of range" % tag)
		if ef.has("op"):
			if not ef["op"] in ["dispel", "cleanse"]:
				errors.append("%s: unknown op '%s'" % [tag, ef["op"]])
			if int(ef.get("count", 1)) < 1:
				errors.append("%s: op count must be >= 1" % tag)
			continue
		if not ef.has("id"):
			errors.append("%s: effect missing id" % tag)
			continue
		if not EffectCatalog.EFFECTS.has(ef["id"]):
			errors.append("%s: unknown effect id '%s'" % [tag, ef["id"]])
			continue
		if ef["id"] == "barrier" and float(ef.get("shield_atk_mult", 0.0)) <= 0.0 and float(ef.get("shield_hp_pct", 0.0)) <= 0.0:
			errors.append("%s: barrier needs shield_atk_mult or shield_hp_pct" % tag)
		if int(ef.get("turns", 1)) < 1 or int(ef.get("turns", 1)) > 5:
			errors.append("%s: effect turns out of range" % tag)
	for up in s.upgrades:
		if not up is Dictionary or up.is_empty():
			errors.append("%s: empty upgrade entry" % tag)
			continue
		for k in up.keys():
			if not k in VALID_UPGRADE_KEYS:
				errors.append("%s: unknown upgrade key '%s'" % [tag, k])
	if s.upgrades.size() > 5:
		errors.append("%s: more than 5 upgrades" % tag)


static func _validate_hero(h: HeroData, errors: Array[String]) -> void:
	var tag := "hero %s" % h.id
	if h.id == "" or h.name == "":
		errors.append("%s: missing id or name" % tag)
	if not h.role in VALID_ROLES:
		errors.append("%s: bad role '%s'" % [tag, h.role])
	if not h.kind in VALID_KINDS:
		errors.append("%s: bad kind '%s'" % [tag, h.kind])
	if h.rarity < 3 or h.rarity > 5:
		errors.append("%s: rarity must be 3..5" % tag)
	if h.skills.size() != h.skill_ids.size():
		errors.append("%s: references missing skills" % tag)
	var actives := 0
	for s in h.skills:
		if not s.passive:
			actives += 1
	if actives < 1:
		errors.append("%s: needs at least one active skill" % tag)
	if h.skills.size() > 0 and h.skills[0].passive:
		errors.append("%s: first skill must be active (used for counters and dual attacks)" % tag)
	if h.kind == "hero" and actives != 3:
		errors.append("%s: playable heroes need exactly 3 active skills (has %d)" % [tag, actives])
	if h.ai.has("skill") and not h.ai["skill"] in VALID_AI_SKILL:
		errors.append("%s: bad ai.skill '%s'" % [tag, h.ai["skill"]])
	if h.ai.has("target") and not h.ai["target"] in VALID_AI_TARGET:
		errors.append("%s: bad ai.target '%s'" % [tag, h.ai["target"]])
	for k in STAT_RANGES.keys():
		var v := float(h.max_stats.get(k, 0.0))
		var r: Array = STAT_RANGES[k]
		if v < r[0] or v > r[1]:
			errors.append("%s: stat %s=%.2f outside [%s, %s]" % [tag, k, v, r[0], r[1]])
	if h.portrait != "" and not ResourceLoader.exists(h.portrait) and not FileAccess.file_exists(h.portrait):
		errors.append("%s: portrait not found at %s" % [tag, h.portrait])
