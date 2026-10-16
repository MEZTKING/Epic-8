extends SceneTree
## Plays a full auto battle through the real battle scene (headless) and
## checks the result overlay appears. Exit 1 on failure or timeout.
##   godot --headless --path . --script tests/scene_smoke.gd

var scene: Control
var frames := 0
var manual_checked := false


func _initialize() -> void:
	HeroDB.load_all()
	scene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	root.add_child(scene)
	# Deterministic demo battle, manual mode first to exercise the input path.
	var pb := DemoTeams.default_battle(7)
	scene.configure(pb["player"], pb["enemy"], 7, false)
	scene.speed_index = 2


func _process(_delta: float) -> bool:
	frames += 1
	if scene.engine != null and scene.engine.awaiting_input and not scene.busy and not manual_checked:
		# Exercise the manual path once: pick skill 1 via the button mapping, cycle a target, confirm.
		scene._on_skill_pressed(0)
		scene._cycle_target()
		var ok: bool = scene.selected_skill >= 0
		scene._confirm()
		manual_checked = true
		if not ok or scene.engine.decisions.is_empty():
			printerr("manual input path failed")
			quit(1)
			return true
		# Then switch to auto for the rest.
		scene._on_auto_toggled(true)
	if scene.finished:
		var r: Dictionary = scene.result
		print("scene finished: winner=%d turns=%d frames=%d decisions=%d" % [r["winner"], r["turns"], frames, r["replay"]["decisions"].size()])
		var ok: bool = scene.overlay.visible and int(r["turns"]) > 0 and manual_checked
		print("PASS scene_smoke" if ok else "FAIL scene_smoke")
		quit(0 if ok else 1)
		return true
	if frames > 20000:
		printerr("timeout after %d frames (turn %d)" % [frames, scene.engine.turn_count])
		quit(1)
		return true
	return false
