extends SceneTree
## Balance harness: runs many seeded battles between preset teams and prints
## win rates. Usage:
##   godot --headless --path . --script tests/balance_harness.gd -- --runs 200
## Add team presets below as the roster grows.

const TEAMS := {
	"burst": ["kaelen", "mira", "vexmoor", "bramble"],
	"sustain": ["thorne", "seraphi", "kaelen", "ilsabet"],
	"control": ["mira", "ilsabet", "thorne", "vexmoor"],
	"grunts": ["grunt", "grunt", "grunt", "grunt"],
}


func _init() -> void:
	HeroDB.load_all()
	var runs := 100
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--runs" and i + 1 < args.size():
			runs = int(args[i + 1])
	var names := TEAMS.keys()
	print("Balance harness: %d runs per matchup, level 60, no gear\n" % runs)
	print("%-10s %-10s %8s %8s %6s %8s" % ["A", "B", "A win%", "B win%", "draw", "avg T"])
	var hero_wins := {}
	var hero_games := {}
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			var wins := [0, 0, 0]
			var turns := 0
			for r in runs:
				var engine := BattleEngine.new(r * 7919 + i * 31 + j)
				engine.setup(_team(TEAMS[a], 0), _team(TEAMS[b], 1))
				var w := engine.run()
				wins[w] += 1
				turns += engine.turn_count
				for id in TEAMS[a]:
					hero_games[id] = int(hero_games.get(id, 0)) + 1
					hero_wins[id] = int(hero_wins.get(id, 0)) + (1 if w == 0 else 0)
				for id in TEAMS[b]:
					hero_games[id] = int(hero_games.get(id, 0)) + 1
					hero_wins[id] = int(hero_wins.get(id, 0)) + (1 if w == 1 else 0)
			print("%-10s %-10s %7.1f%% %7.1f%% %6d %8.1f" % [a, b, 100.0 * wins[0] / runs, 100.0 * wins[1] / runs, wins[2], float(turns) / runs])
	print("\nPer-hero win rate across all matchups (team credit):")
	var ids := hero_games.keys()
	ids.sort_custom(func(x, y): return float(hero_wins[x]) / hero_games[x] > float(hero_wins[y]) / hero_games[y])
	for id in ids:
		print("  %-10s %6.1f%%  (%d games)" % [id, 100.0 * hero_wins[id] / hero_games[id], hero_games[id]])
	quit(0)


func _team(ids: Array, team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for i in ids.size():
		out.append(BattleUnit.new(HeroDB.get_hero(ids[i]), team, i, 60))
	return out
