class_name Stats
extends RefCounted
## Stat dictionary helpers. All stats live in plain Dictionaries so they can be
## serialised to JSON and combined freely (base + gear + buffs).

const KEYS: Array[String] = ["atk", "def", "hp", "spd", "crit_rate", "crit_dmg", "eff", "res"]

## Stats that are stored as a fraction (0.15 == 15%).
const PERCENT_KEYS: Array[String] = ["crit_rate", "crit_dmg", "eff", "res"]


static func empty() -> Dictionary:
	var d := {}
	for k in KEYS:
		d[k] = 0.0
	return d


static func from_dict(src: Dictionary) -> Dictionary:
	var d := empty()
	for k in KEYS:
		if src.has(k):
			d[k] = float(src[k])
	return d


static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := empty()
	for k in KEYS:
		d[k] = float(a.get(k, 0.0)) + float(b.get(k, 0.0))
	return d


static func scale(a: Dictionary, factor: float) -> Dictionary:
	var d := empty()
	for k in KEYS:
		d[k] = float(a.get(k, 0.0)) * factor
	return d


## Hero base stats grow linearly from 35% of their max-level value at level 1
## to 100% at MAX_LEVEL. Percent stats (crit, eff, res) do not scale with level.
const MAX_LEVEL := 60


static func at_level(max_stats: Dictionary, level: int) -> Dictionary:
	var t := clampf(float(level - 1) / float(MAX_LEVEL - 1), 0.0, 1.0)
	var d := empty()
	for k in KEYS:
		var v := float(max_stats.get(k, 0.0))
		if k in PERCENT_KEYS:
			d[k] = v
		else:
			d[k] = roundf(v * (0.35 + 0.65 * t))
	return d
