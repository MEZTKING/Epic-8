class_name Stage
extends RefCounted
## One playable encounter: adventure stage, hunt tier, tower floor or daily dungeon.

var id: String
var type: String = "adventure"   # adventure | hunt | tower | daily
var name: String
var element: String = ""
var chapter: int = 0
var index: int = 0
var tier: int = 0
var floor: int = 0
var difficulty: int = 0
var boss: String = ""
var energy: int = 0
var level: int = 1
var enemies: Array[String] = []
var rewards: Dictionary = {}       # {"gold": int, "xp": int, "materials": {id: n}}
var first_clear: Dictionary = {}   # one-time bonus
var turn_limit_for_star: int = 24
var gear_drop: Dictionary = {}     # {"chance", "rarity_weights", "tier"}
var requires: String = ""          # stage id that must be cleared first
var weekdays: Array[int] = []      # 0 = Sunday .. 6 = Saturday; empty = always
var once: bool = false             # can only be cleared once (tower)


static func from_dict(d: Dictionary) -> Stage:
	var s := Stage.new()
	s.id = str(d.get("id", ""))
	s.type = str(d.get("type", "adventure"))
	s.name = str(d.get("name", s.id))
	s.element = str(d.get("element", ""))
	s.chapter = int(d.get("chapter", 0))
	s.index = int(d.get("index", 0))
	s.tier = int(d.get("tier", 0))
	s.floor = int(d.get("floor", 0))
	s.difficulty = int(d.get("difficulty", 0))
	s.boss = str(d.get("boss", ""))
	s.energy = int(d.get("energy", 0))
	s.level = int(d.get("level", 1))
	for e in d.get("enemies", []):
		s.enemies.append(str(e))
	s.rewards = d.get("rewards", {}).duplicate(true)
	s.first_clear = d.get("first_clear", {}).duplicate(true)
	s.turn_limit_for_star = int(d.get("turn_limit_for_star", 24))
	s.gear_drop = d.get("gear_drop", {}).duplicate(true)
	s.requires = str(d.get("requires", ""))
	for w in d.get("weekdays", []):
		s.weekdays.append(int(w))
	s.once = bool(d.get("once", false))
	return s


func material_rewards() -> Dictionary:
	return rewards.get("materials", {})


func is_open_on(weekday: int) -> bool:
	return weekdays.is_empty() or weekday in weekdays
