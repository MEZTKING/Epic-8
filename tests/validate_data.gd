extends SceneTree
## Headless data validation. Exit code 1 on any error.
##   godot --headless --path . --script tests/validate_data.gd


func _init() -> void:
	var errors := DataValidator.validate()
	for e in errors:
		printerr("DATA ERROR: %s" % e)
	print("%d heroes, %d skills, %d errors" % [HeroDB.all_heroes().size(), HeroDB.all_skills().size(), errors.size()])
	quit(1 if errors.size() > 0 else 0)
