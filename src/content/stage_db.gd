class_name StageDB
extends RefCounted

static var _stages: Dictionary = {}
static var _order: Array[String] = []
static var _loaded := false


static func load_all(force := false) -> void:
	if _loaded and not force:
		return
	_stages.clear()
	_order.clear()
	var f := FileAccess.open("res://data/stages.json", FileAccess.READ)
	if f == null:
		push_error("Cannot open data/stages.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for d in parsed:
			var s := Stage.from_dict(d)
			_stages[s.id] = s
			_order.append(s.id)
	_loaded = true


static func get_stage(id: String) -> Stage:
	load_all()
	return _stages.get(id)


static func all() -> Array[Stage]:
	load_all()
	var out: Array[Stage] = []
	for id in _order:
		out.append(_stages[id])
	return out


static func of_type(type: String) -> Array[Stage]:
	var out: Array[Stage] = []
	for s in all():
		if s.type == type:
			out.append(s)
	return out


static func chapter(c: int) -> Array[Stage]:
	var out: Array[Stage] = []
	for s in of_type("adventure"):
		if s.chapter == c:
			out.append(s)
	return out
