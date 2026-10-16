class_name SkillData
extends RefCounted
## A single hero skill. Loaded from data/skills.json.
##
## target options: "enemy", "all_enemies", "self", "ally", "all_allies"
## effects entries:
##   {"id": "def_down", "chance": 0.75, "turns": 2, "target": "hit"}
##   target: "hit" (the unit this skill hit), "self", "all_allies", "all_enemies",
##           "highest_atk_enemy", "self_before" (applied before damage),
##           "victim" (passives only: the ally that was attacked)
##   barrier: {"id": "barrier", "turns": 2, "shield_atk_mult": 1.0, "shield_hp_pct": 0.0}
##   ops:     {"op": "dispel", "count": 1, "chance": 0.5}   removes buffs from target
##            {"op": "cleanse", "count": 2, "chance": 1.0}  removes debuffs from target
## passives: {"passive": true, "trigger": "on_turn_start"|"on_hit"|"on_ally_attacked"|"on_kill",
##            "chance": 0.35, "cooldown": 2, "effects": [...], "gauge_push": 0, "heal_percent": 0}
## upgrades: ordered list of deltas applied by skill enhancement level, e.g.
##           [{"multiplier": 0.05}, {"chance": 0.1}, {"cooldown": -1}]

var id: String
var name: String
var description: String
var target: String = "enemy"
var multiplier: float = 1.0          # damage = ATK * multiplier (0 for non-damage skills)
var hp_scaling: float = 0.0          # extra damage from attacker max HP
var heal_percent: float = 0.0        # heal = target max HP * heal_percent
var cooldown: int = 0
var gauge_push: float = 0.0          # initiative gauge given to targets (self/allies)
var effects: Array = []
var resolve_cost: int = 0            # cost to empower with Resolve (team resource)
var extra_turn: bool = false         # actor acts again immediately after this skill
var passive: bool = false
var trigger: String = ""
var chance: float = 1.0              # passive trigger chance
var upgrades: Array = []


static func from_dict(d: Dictionary) -> SkillData:
	var s := SkillData.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", s.id))
	s.description = str(d.get("description", ""))
	s.target = str(d.get("target", "enemy"))
	s.multiplier = float(d.get("multiplier", 1.0))
	s.hp_scaling = float(d.get("hp_scaling", 0.0))
	s.heal_percent = float(d.get("heal_percent", 0.0))
	s.cooldown = int(d.get("cooldown", 0))
	s.gauge_push = float(d.get("gauge_push", 0.0))
	s.effects = d.get("effects", []).duplicate(true)
	s.resolve_cost = int(d.get("resolve_cost", 0))
	s.extra_turn = bool(d.get("extra_turn", false))
	s.passive = bool(d.get("passive", false))
	s.trigger = str(d.get("trigger", ""))
	s.chance = float(d.get("chance", 1.0))
	s.upgrades = d.get("upgrades", []).duplicate(true)
	if s.passive:
		s.multiplier = 0.0
	return s


func duplicate() -> SkillData:
	var s := SkillData.new()
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = get(p["name"])
			s.set(p["name"], v.duplicate(true) if v is Array else v)
	return s


func max_level() -> int:
	return upgrades.size()


## Returns a copy with the first `level` upgrades applied (0 = base skill).
func at_level(level: int) -> SkillData:
	if level <= 0 or upgrades.is_empty():
		return self
	var s := duplicate()
	for i in range(mini(level, upgrades.size())):
		var up: Dictionary = upgrades[i]
		s.multiplier += float(up.get("multiplier", 0.0))
		s.heal_percent += float(up.get("heal_percent", 0.0))
		s.gauge_push += float(up.get("gauge_push", 0.0))
		s.cooldown = maxi(s.cooldown + int(up.get("cooldown", 0)), 0)
		s.chance = minf(s.chance + float(up.get("chance", 0.0)), 1.0) if s.passive else s.chance
		if up.has("chance") and not s.passive:
			for ef in s.effects:
				if ef.has("chance"):
					ef["chance"] = minf(float(ef["chance"]) + float(up["chance"]), 1.0)
	return s


func is_damage() -> bool:
	return not passive and (multiplier > 0.0 or hp_scaling > 0.0)


func is_heal() -> bool:
	return heal_percent > 0.0


func targets_enemies() -> bool:
	return target in ["enemy", "all_enemies"]


func is_single_target() -> bool:
	return target in ["enemy", "ally", "self"]
