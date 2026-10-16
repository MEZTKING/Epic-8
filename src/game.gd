extends Node
## Autoload "Game": holds the active profile and the pending battle hand-off
## between the meta screens and the battle scene.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var profile: PlayerProfile
var pending_battle: Dictionary = {}   # {"player": Array[BattleUnit], "enemy": Array[BattleUnit], "seed": int, "auto": bool, "return_to": String, "context": Dictionary}
var last_battle_result: Dictionary = {}


func _ready() -> void:
	HeroDB.load_all()
	profile = SaveSystem.load()
	if profile == null:
		profile = PlayerProfile.new(int(Time.get_unix_time_from_system()))


func save() -> bool:
	return SaveSystem.save(profile) if profile != null else false


## Starts a battle and switches to the battle scene.
func start_battle(player: Array[BattleUnit], enemy: Array[BattleUnit], seed_value: int = -1, auto := false, return_to := MAIN_SCENE, context := {}) -> void:
	if seed_value < 0:
		seed_value = randi()
	pending_battle = {"player": player, "enemy": enemy, "seed": seed_value, "auto": auto, "return_to": return_to, "context": context}
	get_tree().change_scene_to_file(BATTLE_SCENE)


func finish_battle(result: Dictionary) -> void:
	last_battle_result = result
	var back: String = pending_battle.get("return_to", MAIN_SCENE)
	pending_battle = {}
	get_tree().change_scene_to_file(back)
