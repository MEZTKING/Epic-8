class_name BattleReplay
extends RefCounted
## Rebuilds a battle from a replay Dictionary (see BattleEngine.to_replay)
## and plays every recorded decision back through the manual-input API.
## Useful for bug reports, PvP result verification, and spectating.


static func run(replay: Dictionary) -> BattleEngine:
	var engine := BattleEngine.new(int(replay["seed"]))
	var p: Array[BattleUnit] = []
	var e: Array[BattleUnit] = []
	for spec in replay["player"]:
		p.append(BattleUnit.from_spec(spec))
	for spec in replay["enemy"]:
		e.append(BattleUnit.from_spec(spec))
	engine.setup(p, e)
	engine.manual_teams = [0, 1]
	var decisions: Array = replay["decisions"]
	var i := 0
	while not engine.is_over():
		engine.step()
		if engine.awaiting_input:
			if i >= decisions.size():
				push_error("Replay ran out of decisions at turn %d" % engine.turn_count)
				break
			var d: Dictionary = decisions[i]
			i += 1
			var target: BattleUnit = null
			if int(d["target_team"]) >= 0:
				target = engine.unit_at(int(d["target_team"]), int(d["target_slot"]))
			if not engine.submit_action(int(d["skill"]), target, bool(d["empower"])):
				push_error("Replay decision %d was rejected" % i)
				break
	return engine


static func to_json(replay: Dictionary) -> String:
	return JSON.stringify(replay)


static func from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
