class_name SkillData
extends RefCounted
## A single hero skill. Loaded from data/skills.json.
##
## target options: "enemy", "all_enemies", "self", "ally", "all_allies",
##                 "lowest_hp_ally"
## effects entries: {"id": "def_down", "chance": 0.75, "turns": 2, "target": "hit"|"self"|"all_allies"|"all_enemies"}

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
	s.effects = d.get("effects", [])
	s.resolve_cost = int(d.get("resolve_cost", 0))
	return s


func is_damage() -> bool:
	return multiplier > 0.0 or hp_scaling > 0.0


func is_heal() -> bool:
	return heal_percent > 0.0


func targets_enemies() -> bool:
	return target in ["enemy", "all_enemies"]
