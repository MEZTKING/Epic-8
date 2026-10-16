class_name Dialogue
extends RefCounted
## Story dialogue loaded from data/story/*.json. All writing is original.

var id: String
var title: String
var lines: Array[Dictionary] = []    # {"speaker": String, "text": String}
var after_stage: String = ""         # play after this stage is first cleared

static var _by_stage: Dictionary = {}
static var _all: Dictionary = {}
static var _loaded := false


static func load_all(force := false) -> void:
	if _loaded and not force:
		return
	_by_stage.clear()
	_all.clear()
	var dir := DirAccess.open("res://data/story")
	if dir == null:
		push_error("Cannot open data/story")
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/story/" + file, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			push_error("Bad dialogue file %s" % file)
			continue
		var d := Dialogue.new()
		d.id = str(parsed.get("id", file.get_basename()))
		d.title = str(parsed.get("title", ""))
		d.after_stage = str(parsed.get("after_stage", ""))
		for l in parsed.get("lines", []):
			d.lines.append({"speaker": str(l.get("speaker", "Narrator")), "text": str(l.get("text", ""))})
		_all[d.id] = d
		if d.after_stage != "":
			_by_stage[d.after_stage] = d
	_loaded = true


static func get_dialogue(id: String) -> Dialogue:
	load_all()
	return _all.get(id)


static func for_stage(stage_id: String) -> Dialogue:
	load_all()
	return _by_stage.get(stage_id)


static func all() -> Array[Dialogue]:
	load_all()
	var out: Array[Dialogue] = []
	for d in _all.values():
		out.append(d)
	return out


## Returns true the first time a dialogue is seen; records it in the profile.
static func mark_seen(profile: PlayerProfile, dialogue_id: String) -> bool:
	var seen: Dictionary = profile.flags.get("dialogues_seen", {})
	if seen.has(dialogue_id):
		return false
	seen[dialogue_id] = true
	profile.flags["dialogues_seen"] = seen
	return true
