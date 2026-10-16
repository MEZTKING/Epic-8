class_name UnitView
extends PanelContainer
## Visual card for one BattleUnit: portrait, HP, barrier, gauge, statuses.

signal clicked(unit: BattleUnit)

enum Highlight { NONE, ACTOR, VALID_TARGET, SELECTED_TARGET, VALID_ALLY, SELECTED_ALLY }

const ELEMENT_COLORS := {
	Elements.Type.FLAME: Color("#f06a3a"), Elements.Type.FROST: Color("#6fc3f0"),
	Elements.Type.VERDANT: Color("#6fbf5a"), Elements.Type.RADIANT: Color("#f2d35a"),
	Elements.Type.UMBRAL: Color("#9a6fe0"),
}

var unit: BattleUnit
var portrait: TextureRect
var name_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var barrier_bar: ProgressBar
var gauge_bar: ProgressBar
var status_box: HBoxContainer
var frame: StyleBoxFlat
var _base_pos: Vector2
var _highlight: Highlight = Highlight.NONE


func _init(p_unit: BattleUnit) -> void:
	unit = p_unit
	custom_minimum_size = Vector2(300, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	frame = StyleBoxFlat.new()
	frame.bg_color = Color(0.09, 0.1, 0.18, 0.95)
	frame.border_color = Color(0.3, 0.3, 0.4)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	frame.set_content_margin_all(6)
	add_theme_stylebox_override("panel", frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if unit.data.portrait != "" and ResourceLoader.exists(unit.data.portrait):
		portrait.texture = load(unit.data.portrait)
	if unit.team == 1:
		portrait.flip_h = true
	row.add_child(portrait)
	# Placeholder initials drawn over the portrait (SVG text is not rendered by the importer).
	var initials := Label.new()
	initials.text = initials_for(unit.data.name)
	initials.set_anchors_preset(Control.PRESET_FULL_RECT)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 30)
	initials.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	initials.add_theme_constant_override("outline_size", 6)
	initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(initials)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	name_label = Label.new()
	name_label.text = unit.data.name
	name_label.add_theme_color_override("font_color", ELEMENT_COLORS[unit.data.element])
	name_label.clip_text = true
	name_label.tooltip_text = "%s · %s · %d★" % [unit.data.element_name(), unit.data.role.capitalize(), unit.data.rarity]
	col.add_child(name_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.show_percentage = false
	hp_bar.max_value = unit.max_hp()
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.25, 0.8, 0.3)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	col.add_child(hp_bar)

	barrier_bar = ProgressBar.new()
	barrier_bar.custom_minimum_size = Vector2(0, 5)
	barrier_bar.show_percentage = false
	barrier_bar.max_value = unit.max_hp()
	var b_fill := StyleBoxFlat.new()
	b_fill.bg_color = Color(0.5, 0.75, 1.0)
	barrier_bar.add_theme_stylebox_override("fill", b_fill)
	col.add_child(barrier_bar)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 12)
	col.add_child(hp_label)

	gauge_bar = ProgressBar.new()
	gauge_bar.custom_minimum_size = Vector2(0, 5)
	gauge_bar.show_percentage = false
	gauge_bar.max_value = 100.0
	var g_fill := StyleBoxFlat.new()
	g_fill.bg_color = Color(1.0, 0.85, 0.3)
	gauge_bar.add_theme_stylebox_override("fill", g_fill)
	col.add_child(gauge_bar)

	status_box = HBoxContainer.new()
	status_box.add_theme_constant_override("separation", 3)
	col.add_child(status_box)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(unit)
		accept_event()


func refresh() -> void:
	hp_bar.max_value = unit.max_hp()
	hp_bar.value = unit.hp
	barrier_bar.value = unit.shield_value()
	barrier_bar.visible = unit.shield_value() > 0.0
	hp_label.text = "%d / %d%s" % [unit.hp, unit.max_hp(), "  +%d" % unit.shield_value() if unit.shield_value() > 0.0 else ""]
	gauge_bar.value = unit.gauge
	for c in status_box.get_children():
		c.queue_free()
	for e in unit.effects:
		if e["id"] == "barrier":
			continue
		var tag := Label.new()
		var def_ := EffectCatalog.get_effect(e["id"])
		tag.text = "%s %d" % [_abbrev(def_["name"]), int(e["turns"])]
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1, 0.5, 0.5) if def_["kind"] == "debuff" else Color(0.5, 1, 0.6))
		status_box.add_child(tag)
	modulate = Color(1, 1, 1, 1) if unit.alive else Color(0.4, 0.4, 0.4, 0.6)


static func initials_for(name: String) -> String:
	var out := ""
	for p in name.replace("The ", "").split(" "):
		if p != "" and out.length() < 2:
			out += p.substr(0, 1).to_upper()
	return out


static func _abbrev(name: String) -> String:
	var parts := name.split(" ")
	if parts.size() == 1:
		return name.substr(0, 4).to_upper()
	var out := ""
	for p in parts:
		out += p.substr(0, 1).to_upper()
	return out


func set_highlight(mode: Highlight) -> void:
	_highlight = mode
	match mode:
		Highlight.ACTOR: frame.border_color = Color(1.0, 0.85, 0.3)
		Highlight.VALID_TARGET: frame.border_color = Color(0.9, 0.4, 0.4)
		Highlight.SELECTED_TARGET: frame.border_color = Color(1.0, 0.2, 0.2)
		Highlight.VALID_ALLY: frame.border_color = Color(0.4, 0.8, 0.5)
		Highlight.SELECTED_ALLY: frame.border_color = Color(0.3, 1.0, 0.4)
		_: frame.border_color = Color(0.3, 0.3, 0.4)
	frame.set_border_width_all(4 if mode in [Highlight.SELECTED_TARGET, Highlight.SELECTED_ALLY, Highlight.ACTOR] else 2)


## Returns a tween that lunges the card toward the enemy side and back.
func lunge(speed: float) -> Tween:
	var dir := 1.0 if unit.team == 0 else -1.0
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 24.0 * dir, 0.12 / speed)
	tween.tween_property(self, "position:x", position.x, 0.12 / speed)
	return tween


func flash(color: Color, speed: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "modulate", color, 0.06 / speed)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1) if unit.alive else Color(0.4, 0.4, 0.4, 0.6), 0.14 / speed)
	return tween
