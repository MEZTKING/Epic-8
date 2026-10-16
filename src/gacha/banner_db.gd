class_name BannerDB
extends RefCounted

static var _banners: Dictionary = {}
static var _loaded := false


static func load_all(force := false) -> void:
	if _loaded and not force:
		return
	_banners.clear()
	var f := FileAccess.open("res://data/banners.json", FileAccess.READ)
	if f == null:
		push_error("Cannot open data/banners.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for d in parsed:
			var b := Banner.from_dict(d)
			_banners[b.id] = b
	_loaded = true


static func get_banner(id: String) -> Banner:
	load_all()
	return _banners.get(id)


static func all() -> Array[Banner]:
	load_all()
	var out: Array[Banner] = []
	for b in _banners.values():
		out.append(b)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


static func active(now_unix: int) -> Array[Banner]:
	var out: Array[Banner] = []
	for b in all():
		if b.is_active(now_unix):
			out.append(b)
	return out
