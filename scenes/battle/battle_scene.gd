extends Control
## The battle screen. Drives a BattleEngine step by step, animates each
## action, and collects player input for manual teams.

const SPEEDS := [1.0, 2.0, 3.0]
const ORDER_PREVIEW := 8

var engine: BattleEngine
var views: Dictionary = {}          # BattleUnit -> UnitView
var auto := false
var speed_index := 0
var selected_skill := -1
var selected_target: BattleUnit = null
var empower := false
var busy := false
var finished := false
var result: Dictionary = {}
var _anim_queue: Array = []
var _frames := 0

var player_col: VBoxContainer
var enemy_col: VBoxContainer
var order_bar: HBoxContainer
var log_box: RichTextLabel
var skill_buttons: Array[Button] = []
var resolve_button: Button
var resolve_bar: ProgressBar
var auto_button: Button
var speed_button: Button
var turn_label: Label
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: Label
var floating_layer: Control


func _ready() -> void:
	if player_col == null:
		_build_ui()
	if engine != null:
		return  # configured before entering the tree (tests, screenshots)
	var game := get_node_or_null("/root/Game")
	var pb: Dictionary = game.pending_battle if game != null else {}
	if pb.is_empty():
		pb = DemoTeams.default_battle(42)
	configure(pb["player"], pb["enemy"], int(pb["seed"]), bool(pb.get("auto", false)))


func configure(player: Array[BattleUnit], enemy: Array[BattleUnit], seed_value: int, p_auto: bool) -> void:
	if player_col == null:
		_build_ui()
	engine = BattleEngine.new(seed_value)
	engine.setup(player, enemy)
	auto = p_auto
	_apply_manual_teams()
	engine.action_resolved.connect(_on_action_resolved)
	engine.unit_defeated.connect(_on_unit_defeated)
	engine.input_requested.connect(_on_input_requested)
	for c in player_col.get_children():
		c.queue_free()
	for c in enemy_col.get_children():
		c.queue_free()
	views.clear()
	for u in engine.units:
		var v := UnitView.new(u)
		v.clicked.connect(_on_unit_clicked)
		(player_col if u.team == 0 else enemy_col).add_child(v)
		views[u] = v
	_refresh_all()
	_set_input_enabled(false)
	call_deferred("_advance")

# ---------------------------------------------------------------- UI build

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	# Top bar: turn order + controls
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vbox.add_child(top)
	turn_label = Label.new()
	turn_label.custom_minimum_size = Vector2(90, 0)
	top.add_child(turn_label)
	order_bar = HBoxContainer.new()
	order_bar.add_theme_constant_override("separation", 4)
	order_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(order_bar)
	auto_button = Button.new()
	auto_button.toggle_mode = true
	auto_button.text = "Auto (A)"
	auto_button.toggled.connect(_on_auto_toggled)
	top.add_child(auto_button)
	speed_button = Button.new()
	speed_button.text = "Speed 1x (S)"
	speed_button.pressed.connect(_cycle_speed)
	top.add_child(speed_button)
	var quit := Button.new()
	quit.text = "Retreat"
	quit.pressed.connect(func(): _finish(1, true))
	top.add_child(quit)

	# Middle: player column | log | enemy column
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	vbox.add_child(mid)
	player_col = VBoxContainer.new()
	player_col.add_theme_constant_override("separation", 6)
	mid.add_child(player_col)
	log_box = RichTextLabel.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	log_box.bbcode_enabled = true
	log_box.add_theme_font_size_override("normal_font_size", 13)
	mid.add_child(log_box)
	enemy_col = VBoxContainer.new()
	enemy_col.add_theme_constant_override("separation", 6)
	mid.add_child(enemy_col)

	# Bottom: skills + resolve
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 44)
		b.toggle_mode = true
		b.pressed.connect(_on_skill_pressed.bind(i))
		bottom.add_child(b)
		skill_buttons.append(b)
	resolve_button = Button.new()
	resolve_button.toggle_mode = true
	resolve_button.custom_minimum_size = Vector2(140, 44)
	resolve_button.toggled.connect(func(on): empower = on; _refresh_skill_buttons())
	bottom.add_child(resolve_button)
	var rbox := VBoxContainer.new()
	rbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(rbox)
	var rlabel := Label.new()
	rlabel.name = "ResolveLabel"
	rlabel.text = "Resolve"
	rlabel.add_theme_font_size_override("font_size", 12)
	rbox.add_child(rlabel)
	resolve_bar = ProgressBar.new()
	resolve_bar.max_value = BattleEngine.RESOLVE_MAX
	resolve_bar.show_percentage = false
	resolve_bar.custom_minimum_size = Vector2(160, 14)
	var r_fill := StyleBoxFlat.new()
	r_fill.bg_color = Color(0.6, 0.4, 1.0)
	resolve_bar.add_theme_stylebox_override("fill", r_fill)
	rbox.add_child(resolve_bar)
	var confirm := Button.new()
	confirm.text = "Confirm (Enter)"
	confirm.custom_minimum_size = Vector2(150, 44)
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)

	floating_layer = Control.new()
	floating_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floating_layer)

	overlay = PanelContainer.new()
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.custom_minimum_size = Vector2(420, 220)
	add_child(overlay)
	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 12)
	overlay.add_child(ov)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 40)
	ov.add_child(overlay_title)
	overlay_body = Label.new()
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(overlay_body)
	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(_continue)
	ov.add_child(cont)

# ---------------------------------------------------------------- flow

func _advance() -> void:
	if finished or busy or engine == null:
		return
	if engine.is_over():
		_finish(engine.winner)
		return
	if engine.awaiting_input:
		return
	engine.step()
	_after_step()


func _after_step() -> void:
	_refresh_log()
	if _anim_queue.is_empty():
		_refresh_all()
		if engine.is_over():
			_finish(engine.winner)
		elif engine.awaiting_input:
			_begin_input(engine.current_actor)
		else:
			call_deferred("_advance")
		return
	_play_queue()


func _play_queue() -> void:
	busy = true
	_set_input_enabled(false)
	while not _anim_queue.is_empty():
		var item: Dictionary = _anim_queue.pop_front()
		await _animate(item)
	busy = false
	_refresh_all()
	if engine.is_over():
		_finish(engine.winner)
	elif engine.awaiting_input:
		_begin_input(engine.current_actor)
	else:
		await get_tree().create_timer(0.15 / _speed()).timeout
		_advance()


func _speed() -> float:
	return SPEEDS[speed_index]


func _animate(item: Dictionary) -> void:
	var actor: BattleUnit = item["actor"]
	var skill: SkillData = item["skill"]
	var av: UnitView = views.get(actor)
	if av != null and skill.is_damage():
		await av.lunge(_speed()).finished
	for r in item["results"]:
		var t: BattleUnit = r["target"]
		var tv: UnitView = views.get(t)
		if tv == null:
			continue
		var pos := tv.global_position + Vector2(tv.size.x * 0.5, 10)
		if r["damage"] > 0.0 or r["absorbed"] > 0.0:
			tv.flash(Color(1, 0.4, 0.4), _speed())
			var txt := "%d" % int(r["damage"])
			if r["crit"]:
				txt += "!"
			if r["absorbed"] > 0.0:
				txt += " (%d)" % int(r["absorbed"])
			FloatingText.spawn(floating_layer, pos, txt, Color(1, 0.95, 0.5) if r["crit"] else Color(1, 1, 1), _speed(), 26 if r["crit"] else 22)
		if r["heal"] > 0.0:
			tv.flash(Color(0.5, 1, 0.6), _speed())
			FloatingText.spawn(floating_layer, pos + Vector2(0, 24), "+%d" % int(r["heal"]), Color(0.5, 1, 0.6), _speed())
		var y := 48.0
		for ef in r["effects"]:
			var def_ := EffectCatalog.get_effect(ef) if EffectCatalog.EFFECTS.has(ef) else {"name": ef.capitalize(), "kind": "buff"}
			FloatingText.spawn(floating_layer, pos + Vector2(0, y), def_["name"], Color(1, 0.6, 0.6) if def_.get("kind") == "debuff" else Color(0.7, 0.9, 1), _speed(), 16)
			y += 18.0
		tv.refresh()
	await get_tree().create_timer(0.35 / _speed()).timeout


func _on_action_resolved(actor: BattleUnit, skill: SkillData, results: Array) -> void:
	_anim_queue.append({"actor": actor, "skill": skill, "results": results.duplicate()})


func _on_unit_defeated(unit: BattleUnit) -> void:
	var v: UnitView = views.get(unit)
	if v != null:
		v.refresh()


func _on_input_requested(_unit: BattleUnit) -> void:
	pass  # handled after animations in _play_queue / _after_step


func _finish(winner: int, retreated := false) -> void:
	if finished:
		return
	finished = true
	_set_input_enabled(false)
	result = {"winner": winner, "turns": engine.turn_count, "retreated": retreated, "replay": engine.to_replay(), "survivors": engine.living(0).size()}
	overlay_title.text = "Victory" if winner == 0 else ("Retreated" if retreated else ("Defeat" if winner == 1 else "Draw"))
	overlay_body.text = "%d turns · %d allies standing" % [engine.turn_count, engine.living(0).size()]
	overlay.visible = true
	_refresh_all()


func _continue() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and not game.pending_battle.is_empty():
		game.finish_battle(result)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---------------------------------------------------------------- input

func _begin_input(actor: BattleUnit) -> void:
	if auto:
		_auto_decide()
		return
	_set_input_enabled(true)
	empower = false
	resolve_button.button_pressed = false
	var idx := engine.choose_skill_index(actor)
	_select_skill(idx)
	for u in engine.units:
		views[u].set_highlight(UnitView.Highlight.ACTOR if u == actor else UnitView.Highlight.NONE)
	_refresh_targets()


func _auto_decide() -> void:
	var actor := engine.current_actor
	var idx := engine.choose_skill_index(actor)
	var skill := actor.skill(idx)
	var emp := skill.resolve_cost > 0 and engine.resolve[actor.team] >= skill.resolve_cost
	engine.submit_action(idx, engine.choose_target(actor, skill), emp)
	_after_step()


func _select_skill(idx: int) -> void:
	var actor := engine.current_actor
	if actor == null or idx < 0 or idx >= actor.data.skills.size():
		return
	var s := actor.skill(idx)
	if s.passive or not actor.skill_ready(idx):
		return
	selected_skill = idx
	selected_target = engine.choose_target(actor, s)
	if not s.is_single_target():
		selected_target = null
	_refresh_skill_buttons()
	_refresh_targets()


func _valid_targets() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var actor := engine.current_actor
	if actor == null or selected_skill < 0:
		return out
	var s := actor.skill(selected_skill)
	if not s.is_single_target():
		return out
	if s.target == "self":
		out.append(actor)
		return out
	var forced := engine.provoker_of(actor)
	if s.targets_enemies() and forced != null:
		out.append(forced)
		return out
	out.append_array(engine.living(1 - actor.team) if s.targets_enemies() else engine.living(actor.team))
	return out


func _refresh_targets() -> void:
	var valid := _valid_targets()
	var actor := engine.current_actor
	for u in engine.units:
		var v: UnitView = views[u]
		var ally := actor != null and u.team == actor.team
		if u == actor:
			v.set_highlight(UnitView.Highlight.ACTOR)
		elif u == selected_target:
			v.set_highlight(UnitView.Highlight.SELECTED_ALLY if ally else UnitView.Highlight.SELECTED_TARGET)
		elif u in valid:
			v.set_highlight(UnitView.Highlight.VALID_ALLY if ally else UnitView.Highlight.VALID_TARGET)
		else:
			v.set_highlight(UnitView.Highlight.NONE)
	if actor != null and selected_skill >= 0 and not actor.skill(selected_skill).is_single_target():
		var s := actor.skill(selected_skill)
		var enemies := s.targets_enemies()
		for u in (engine.living(1 - actor.team) if enemies else engine.living(actor.team)):
			if u != actor:
				views[u].set_highlight(UnitView.Highlight.SELECTED_TARGET if enemies else UnitView.Highlight.SELECTED_ALLY)


func _on_unit_clicked(unit: BattleUnit) -> void:
	if not engine.awaiting_input or busy or auto:
		return
	if unit in _valid_targets():
		selected_target = unit
		_refresh_targets()


func _on_skill_pressed(idx: int) -> void:
	if not engine.awaiting_input or busy:
		_refresh_skill_buttons()
		return
	_select_skill(idx)


func _confirm() -> void:
	if not engine.awaiting_input or busy or auto or selected_skill < 0:
		return
	var actor := engine.current_actor
	var s := actor.skill(selected_skill)
	var target := selected_target
	if s.is_single_target() and (target == null or not target.alive):
		return
	var emp := empower and s.resolve_cost > 0 and engine.resolve[actor.team] >= s.resolve_cost
	if engine.submit_action(selected_skill, target, emp):
		selected_skill = -1
		selected_target = null
		_set_input_enabled(false)
		_after_step()


func _cycle_target() -> void:
	var valid := _valid_targets()
	if valid.is_empty():
		return
	var i := valid.find(selected_target)
	selected_target = valid[(i + 1) % valid.size()]
	_refresh_targets()


func _apply_manual_teams() -> void:
	var mt: Array[int] = []
	if not auto:
		mt.append(0)
	engine.manual_teams = mt


func _on_auto_toggled(on: bool) -> void:
	auto = on
	_apply_manual_teams()
	auto_button.button_pressed = on
	if auto and engine.awaiting_input and not busy and not finished:
		_set_input_enabled(false)
		_auto_decide()


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	speed_button.text = "Speed %dx (S)" % int(SPEEDS[speed_index])


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		if event.is_action_pressed("confirm_action"):
			_continue()
		return
	if event.is_action_pressed("toggle_auto"):
		_on_auto_toggled(not auto)
	elif event.is_action_pressed("cycle_speed"):
		_cycle_speed()
	elif event.is_action_pressed("skill_1"):
		_on_skill_pressed(0)
	elif event.is_action_pressed("skill_2"):
		_on_skill_pressed(1)
	elif event.is_action_pressed("skill_3"):
		_on_skill_pressed(2)
	elif event.is_action_pressed("cycle_target"):
		_cycle_target()
	elif event.is_action_pressed("toggle_resolve"):
		resolve_button.button_pressed = not resolve_button.button_pressed
	elif event.is_action_pressed("confirm_action"):
		_confirm()

# ---------------------------------------------------------------- refresh

func _set_input_enabled(on: bool) -> void:
	for b in skill_buttons:
		b.disabled = not on
	resolve_button.disabled = not on
	if not on:
		for b in skill_buttons:
			b.button_pressed = false


func _refresh_skill_buttons() -> void:
	var actor := engine.current_actor if engine != null else null
	var active_idx := 0
	for i in range(3):
		var b := skill_buttons[i]
		if actor == null:
			b.text = "—"
			b.disabled = true
			continue
		# Map the 3 buttons to the actor's active (non-passive) skills.
		var idx := -1
		var seen := 0
		for k in actor.data.skills.size():
			if actor.skill(k).passive:
				continue
			if seen == i:
				idx = k
				break
			seen += 1
		if idx < 0:
			b.text = "—"
			b.disabled = true
			b.set_meta("skill_index", -1)
			continue
		var s := actor.skill(idx)
		var cd := int(actor.cooldowns.get(idx, 0))
		b.text = "%d. %s%s%s" % [i + 1, s.name, "  (CD %d)" % cd if cd > 0 else "", "  [R %d]" % s.resolve_cost if s.resolve_cost > 0 else ""]
		b.tooltip_text = s.description
		b.disabled = not engine.awaiting_input or cd > 0
		b.button_pressed = idx == selected_skill
		b.set_meta("skill_index", idx)
		active_idx += 1
	if actor != null and selected_skill >= 0:
		var s := actor.skill(selected_skill)
		var can := s.resolve_cost > 0 and engine.resolve[actor.team] >= s.resolve_cost
		resolve_button.disabled = not can or not engine.awaiting_input
		resolve_button.text = "Resolve ×1.25 (R)" if can else "Resolve"
		if not can:
			resolve_button.button_pressed = false
			empower = false


func _on_skill_button_index(i: int) -> int:
	return int(skill_buttons[i].get_meta("skill_index", -1))


func _refresh_order_bar() -> void:
	for c in order_bar.get_children():
		c.queue_free()
	var order := engine.projected_order(ORDER_PREVIEW)
	for i in order.size():
		var u := order[i]
		var t := TextureRect.new()
		var sz := 44 if i == 0 else 32
		t.custom_minimum_size = Vector2(sz, sz)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if u.data.portrait != "" and ResourceLoader.exists(u.data.portrait):
			t.texture = load(u.data.portrait)
		t.tooltip_text = u.display_name()
		t.modulate = Color(0.75, 0.9, 1.0) if u.team == 0 else Color(1.0, 0.8, 0.8)
		order_bar.add_child(t)


func _refresh_log() -> void:
	var lines := engine.log_lines
	var start := maxi(lines.size() - 40, 0)
	log_box.clear()
	for i in range(start, lines.size()):
		var l := lines[i]
		if l.begins_with("T"):
			log_box.append_text("[b]%s[/b]\n" % l)
		else:
			log_box.append_text("%s\n" % l)


func _refresh_all() -> void:
	for u in engine.units:
		views[u].refresh()
	turn_label.text = "Turn %d" % engine.turn_count
	resolve_bar.value = engine.resolve[0]
	var rl := resolve_bar.get_parent().get_node_or_null("ResolveLabel")
	if rl != null:
		rl.text = "Resolve %d / %d" % [engine.resolve[0], BattleEngine.RESOLVE_MAX]
	_refresh_order_bar()
	_refresh_skill_buttons()
	_refresh_log()
