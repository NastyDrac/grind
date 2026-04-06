extends CanvasLayer
class_name Gym

# ─── Layout ───────────────────────────────────────────────────────────────────
const UIBAR_HEIGHT : float = 50.0
const MARGIN       : float = 40.0

# ─── Training config ──────────────────────────────────────────────────────────
const TRAINING_SLOTS : int = 3          # how many choices to offer
const BOOST_MIN      : int = 1          # minimum stat increase per choice
const BOOST_MAX      : int = 1          # maximum stat increase per choice

# ─── State ────────────────────────────────────────────────────────────────────
var run  : RunManager
var _rng : RandomNumberGenerator

# ─── Built nodes ──────────────────────────────────────────────────────────────
var choice_container : HBoxContainer
var leave_button     : Button
var subtitle_label   : Label

signal gym_closed

# ─── Stat metadata ────────────────────────────────────────────────────────────

func _stat_display_name(stat_type: Stat.STAT) -> String:
	match stat_type:
		Stat.STAT.SWAG:    return "Swag"
		Stat.STAT.MARBLES: return "Marbles"
		Stat.STAT.GUTS:    return "Guts"
		Stat.STAT.BANG:    return "Bang"
		Stat.STAT.HUSTLE:  return "Hustle"
		Stat.STAT.MOJO:    return "Mojo"
		_: return "???"

func _stat_color(stat_type: Stat.STAT) -> Color:
	match stat_type:
		Stat.STAT.SWAG:    return Color(0.95, 0.85, 0.20)   # gold
		Stat.STAT.MARBLES: return Color(0.30, 0.75, 1.00)   # sky blue
		Stat.STAT.GUTS:    return Color(0.95, 0.35, 0.35)   # red
		Stat.STAT.BANG:    return Color(1.00, 0.60, 0.10)   # orange
		Stat.STAT.HUSTLE:  return Color(0.40, 0.90, 0.40)   # green
		Stat.STAT.MOJO:    return Color(0.75, 0.35, 1.00)   # purple
		_: return Color.WHITE

func _stat_icon_path(stat_type: Stat.STAT) -> String:
	match stat_type:
		Stat.STAT.SWAG:    return "res://Art/swag.png"
		Stat.STAT.MARBLES: return "res://Art/marbles.png"
		Stat.STAT.GUTS:    return "res://Art/guts.png"
		Stat.STAT.BANG:    return "res://Art/bang.png"
		Stat.STAT.HUSTLE:  return "res://Art/hustle.png"
		Stat.STAT.MOJO:    return "res://Art/mojo.png"
		_: return ""

func _stat_flavour(stat_type: Stat.STAT) -> String:
	match stat_type:
		Stat.STAT.SWAG:    return "Work the mirror. Confidence is a muscle."
		Stat.STAT.MARBLES: return "Chess drills until your brain hurts."
		Stat.STAT.GUTS:    return "Ice baths and the will to keep going."
		Stat.STAT.BANG:    return "Heavy bag work. Pure, uncut power."
		Stat.STAT.HUSTLE:  return "Sprint intervals. No days off."
		Stat.STAT.MOJO:    return "Vibe calibration. Trust the energy."
		_: return ""

# ─── Build the UI ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 1
	_build_ui()

func _build_ui() -> void:
	# ── Backdrop ──
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

	# ── Root VBox ──
	var root_vbox := VBoxContainer.new()
	root_vbox.anchor_right  = 1.0
	root_vbox.anchor_bottom = 1.0
	root_vbox.offset_left   =  16.0
	root_vbox.offset_top    =  10.0
	root_vbox.offset_right  = -16.0
	root_vbox.offset_bottom = -10.0
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# ── Header row ──
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "The Gym"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	header.add_child(title_lbl)

	leave_button = Button.new()
	leave_button.text = "Skip Training"
	leave_button.pressed.connect(_on_leave_pressed)
	header.add_child(leave_button)

	# ── Subtitle ──
	subtitle_label = Label.new()
	subtitle_label.text = "Choose one training regimen to boost a stat permanently."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	root_vbox.add_child(subtitle_label)

	root_vbox.add_child(HSeparator.new())

	# ── Choice area — centred, fills remaining space ──
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

func display_gym(run_manager: RunManager) -> void:
	run  = run_manager
	_rng = run_manager.rng
	_populate_choices()

# ─── Choice population ────────────────────────────────────────────────────────

func _populate_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

	# Pick TRAINING_SLOTS distinct stats at random
	var all_types : Array = Stat.STAT.values()
	all_types.shuffle()
	var chosen_types : Array = all_types.slice(0, TRAINING_SLOTS)

	for stat_type in chosen_types:
		var boost : int = _rng.randi_range(BOOST_MIN, BOOST_MAX)
		var stat  : Stat = _find_stat(stat_type)
		var current_val : int = stat.value if stat else 0

		choice_container.add_child(_build_choice_card(stat_type, stat, boost, current_val))

func _find_stat(stat_type: Stat.STAT) -> Stat:
	# Always modify the permanent CharacterData stats, not the combat copies.
	if run and run.character:
		for s in run.character.stats:
			if s.stat_type == stat_type:
				return s
	return null

# ─── Build a single choice card ───────────────────────────────────────────────

func _build_choice_card(
		stat_type  : Stat.STAT,
		stat       : Stat,
		boost      : int,
		current_val: int) -> PanelContainer:

	var col  := _stat_color(stat_type)
	var name := _stat_display_name(stat_type)
	var icon_path := _stat_icon_path(stat_type)
	var new_val := current_val + boost

	# Outer panel — fixed width so cards line up neatly
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 0)

	# Tinted StyleBox border to hint at the stat colour
	var style := StyleBoxFlat.new()
	style.bg_color          = Color(col.r, col.g, col.b, 0.10)
	style.border_color      = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# ── Icon + name row ──
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(name_row)

	var icon_tex := TextureRect.new()
	icon_tex.texture = load(icon_path) if icon_path != "" else null
	icon_tex.custom_minimum_size = Vector2(32, 32)
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	name_row.add_child(icon_tex)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_lbl)

	vbox.add_child(HSeparator.new())

	# ── Flavour text ──
	var flavour := Label.new()
	flavour.text            = _stat_flavour(stat_type)
	flavour.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	flavour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavour.add_theme_font_size_override("font_size", 11)
	flavour.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(flavour)

	# ── Stat value preview ──
	var value_lbl := Label.new()
	value_lbl.text = "%d  →  %d  (+%d)" % [current_val, new_val, boost]
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.add_theme_color_override("font_color", Color(0.50, 1.00, 0.50))
	vbox.add_child(value_lbl)

	# ── Train button ──
	var btn := Button.new()
	btn.text = "Train  %s" % name
	btn.pressed.connect(_on_train_pressed.bind(stat, boost, btn))
	vbox.add_child(btn)

	return card

# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_train_pressed(stat: Stat, boost: int, btn: Button) -> void:
	if not stat:
		return

	# Write boost to the permanent CharacterData stat.
	stat.modify_stat(boost)

	# Push the updated permanent values into the Character's combat copies
	# and recalculate max HP (awarding the delta to current HP).
	if run.player:
		run.player.sync_from_data()

	_lock_all_buttons()

	var original_text := btn.text
	btn.text = "✔  Done!"
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(btn):
		btn.text = original_text
	run.close_gym()

func _on_leave_pressed() -> void:
	run.close_gym()

# ─── Helpers ──────────────────────────────────────────────────────────────────

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
