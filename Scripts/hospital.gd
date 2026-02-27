extends CanvasLayer
class_name Hospital

# ─── Layout ───────────────────────────────────────────────────────────────────
const UIBAR_HEIGHT : float = 50.0
const MARGIN       : float = 40.0

# ─── Healing tiers ────────────────────────────────────────────────────────────
# Each entry: [percent_healed, gold_cost, label, flavour]
const TIERS : Array = [
	[25,  30,  "Patch Up",      "A quick bandage and some aspirin. Better than nothing."],
	[50,  60,  "Full Checkup",  "Proper treatment. You'll be feeling yourself again."],
	[100, 110, "Full Recovery", "Everything fixed. Like it never happened."],
]

# ─── State ────────────────────────────────────────────────────────────────────
var run : RunManager

# ─── Built nodes ──────────────────────────────────────────────────────────────
var gold_label       : Label
var health_label     : Label
var choice_container : HBoxContainer

signal hospital_closed

# ─── Build the UI ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 1
	_build_ui()

func _build_ui() -> void:
	var panel := Panel.new()
	panel.anchor_left   = 0.0
	panel.anchor_top    = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   =  MARGIN
	panel.offset_top    =  UIBAR_HEIGHT
	panel.offset_right  = -MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.anchor_right  = 1.0
	root_vbox.anchor_bottom = 1.0
	root_vbox.offset_left   =  16.0
	root_vbox.offset_top    =  10.0
	root_vbox.offset_right  = -16.0
	root_vbox.offset_bottom = -10.0
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "The Hospital"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	header.add_child(title_lbl)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 14)
	header.add_child(gold_label)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.pressed.connect(_on_leave_pressed)
	header.add_child(leave_btn)

	# ── Health status bar ──
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(health_label)

	root_vbox.add_child(HSeparator.new())

	# ── Choice cards — vertically centred ──
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer_top)

	choice_container = HBoxContainer.new()
	choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_container.add_theme_constant_override("separation", 24)
	root_vbox.add_child(choice_container)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer_bot)

# ─── Public entry point ───────────────────────────────────────────────────────

func display_hospital(run_manager: RunManager) -> void:
	run = run_manager
	_refresh_labels()
	_populate_choices()

# ─── Populate ─────────────────────────────────────────────────────────────────

func _get_max_health() -> int:
	if run.character.max_health and run.player:
		return run.character.max_health.calculate(run.player)
	return 0

func _populate_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

	var max_hp     : int = _get_max_health()
	var current_hp : int = run.character.current_health
	var gold       : int = run.character.gold

	for tier in TIERS:
		var pct     : int    = tier[0]
		var cost    : int    = tier[1]
		var label   : String = tier[2]
		var flavour : String = tier[3]

		var heal_amount : int  = int(max_hp * pct / 100.0)
		var new_hp      : int  = mini(current_hp + heal_amount, max_hp)
		var actual_heal : int  = new_hp - current_hp
		var already_full       : bool = current_hp >= max_hp
		var cant_afford        : bool = gold < cost

		choice_container.add_child(
			_build_tier_card(label, flavour, pct, cost, actual_heal, current_hp, new_hp, max_hp, already_full, cant_afford)
		)

func _build_tier_card(
		label       : String,
		flavour     : String,
		pct         : int,
		cost        : int,
		actual_heal : int,
		current_hp  : int,
		new_hp      : int,
		max_hp      : int,
		already_full: bool,
		cant_afford : bool) -> PanelContainer:

	var col := Color(0.20, 0.85, 0.50)   # medical green

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(col.r, col.g, col.b, 0.08)
	style.border_color = col if not (already_full or cant_afford) else Color(0.40, 0.40, 0.40)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# ── Title ──
	var title_lbl := Label.new()
	title_lbl.text = label
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", col)
	vbox.add_child(title_lbl)

	# ── Heal percentage badge ──
	var pct_lbl := Label.new()
	pct_lbl.text = "Heals %d%% of max HP" % pct
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pct_lbl)

	vbox.add_child(HSeparator.new())

	# ── Flavour ──
	var flav_lbl := Label.new()
	flav_lbl.text          = flavour
	flav_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flav_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flav_lbl.add_theme_font_size_override("font_size", 11)
	flav_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(flav_lbl)

	# ── HP preview ──
	var hp_lbl := Label.new()
	if already_full:
		hp_lbl.text = "Already at full health"
		hp_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		hp_lbl.text = "%d  →  %d  (+%d)" % [current_hp, new_hp, actual_heal]
		hp_lbl.add_theme_color_override("font_color", Color(0.50, 1.00, 0.50))
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hp_lbl)

	# ── Buy button ──
	var btn := Button.new()
	btn.text     = "Heal  (%d Gold)" % cost
	btn.disabled = already_full or cant_afford
	btn.pressed.connect(_on_heal_pressed.bind(actual_heal, cost, btn))
	vbox.add_child(btn)

	return card

# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_heal_pressed(actual_heal: int, cost: int, btn: Button) -> void:
	run.character.gold          -= cost
	run.character.current_health = mini(
		run.character.current_health + actual_heal,
		_get_max_health()
	)

	if run.ui_bar:
		run.ui_bar.set_gold()
		run.ui_bar.set_health()

	_lock_all_buttons()
	btn.text = "✔  Healed!"
	await get_tree().create_timer(0.8).timeout
	run.close_hospital()

func _on_leave_pressed() -> void:
	run.close_hospital()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _refresh_labels() -> void:
	if run and run.character:
		gold_label.text = "Gold: %d" % run.character.gold
		var max_hp : int = _get_max_health()
		health_label.text = "Current HP: %d / %d" % [run.character.current_health, max_hp]

func _lock_all_buttons() -> void:
	for card in choice_container.get_children():
		for node in _get_all_children(card):
			if node is Button:
				node.disabled = true

func _get_all_children(node: Node) -> Array:
	var result : Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result
