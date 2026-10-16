class_name HeroData
extends RefCounted
## Static definition of a hero. Loaded from data/heroes.json.

var id: String
var name: String
var title: String
var element: Elements.Type
var role: String              # "warrior", "knight", "mage", "ranger", "healer", "assassin"
var rarity: int = 3           # 3..5 base rarity
var max_stats: Dictionary     # stats at level 60 with no gear
var skill_ids: Array[String] = []
var skills: Array[SkillData] = []


static func from_dict(d: Dictionary, skill_lookup: Dictionary) -> HeroData:
	var h := HeroData.new()
	h.id = str(d.get("id", ""))
	h.name = str(d.get("name", h.id))
	h.title = str(d.get("title", ""))
	h.element = Elements.parse(str(d.get("element", "flame")))
	h.role = str(d.get("role", "warrior"))
	h.rarity = int(d.get("rarity", 3))
	h.max_stats = Stats.from_dict(d.get("max_stats", {}))
	for sid in d.get("skills", []):
		h.skill_ids.append(str(sid))
		if skill_lookup.has(sid):
			h.skills.append(skill_lookup[sid])
		else:
			push_error("Hero %s references missing skill %s" % [h.id, sid])
	return h


func element_name() -> String:
	return Elements.NAMES[element]
