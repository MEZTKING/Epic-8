class_name SaveSystem
extends RefCounted
## Local save/load with a checksum. The checksum deters casual editing only;
## anything that must be trustworthy (purchases, PvP results) needs a server.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const VERSION := 1
const SALT := "covenant-of-stars-v1"

static var last_error: String = ""


static func checksum(payload: String) -> String:
	return (payload + SALT).sha256_text()


static func encode(profile: PlayerProfile) -> String:
	var payload := JSON.stringify(profile.to_dict())
	return JSON.stringify({"version": VERSION, "checksum": checksum(payload), "data": payload})


## Returns null and sets last_error on failure.
static func decode(text: String) -> PlayerProfile:
	last_error = ""
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		last_error = "save is not valid JSON"
		return null
	if int(parsed.get("version", 0)) > VERSION:
		last_error = "save was written by a newer version"
		return null
	var payload := str(parsed.get("data", ""))
	if checksum(payload) != str(parsed.get("checksum", "")):
		last_error = "checksum mismatch (file was edited or corrupted)"
		return null
	var data = JSON.parse_string(payload)
	if not data is Dictionary:
		last_error = "save payload is not valid JSON"
		return null
	return PlayerProfile.from_dict(data)


static func save(profile: PlayerProfile, path: String = SAVE_PATH) -> bool:
	last_error = ""
	if FileAccess.file_exists(path):
		var old := FileAccess.open(path, FileAccess.READ)
		if old != null:
			var bak := FileAccess.open(path.get_basename() + ".bak.json", FileAccess.WRITE)
			if bak != null:
				bak.store_string(old.get_as_text())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		last_error = "cannot open %s for writing" % path
		return false
	f.store_string(encode(profile))
	return true


static func load(path: String = SAVE_PATH) -> PlayerProfile:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "no save file"
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "cannot open %s" % path
		return null
	return decode(f.get_as_text())
