extends SceneTree
## Renders the battle scene for a few frames and saves a PNG. Needs a display
## (use xvfb-run). Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/screenshot.gd -- out.png

var scene: Control
var frames := 0
var out_path := "screenshot.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	HeroDB.load_all()
	root.content_scale_size = Vector2i(1280, 720)
	scene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	root.add_child(scene)
	var pb := DemoTeams.default_battle(11)
	scene.configure(pb["player"], pb["enemy"], 11, true)
	scene.speed_index = 2


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 90:
		scene._on_auto_toggled(false)
	if frames == 140:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out_path)
		print("saved %s (%dx%d)" % [out_path, img.get_width(), img.get_height()])
		quit(0)
		return true
	return false
