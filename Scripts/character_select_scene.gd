extends Control
class_name CharacterSelect

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────────────────────────────────────

## Assign all playable CharacterData resources here in the Inspector.
@export var characters : Array[CharacterData] = []

## Path to your RunManager scene.
@export var run_manager_scene : PackedScene

# ─────────────────────────────────────────────────────────────────────────────
#  STAT METADATA  (mirrors gym.gd so colours stay consistent)
# ─────────────────────────────────────────────────────────────────────────────

const STAT_META : Array = [
	# [ STAT enum,          display name,  icon path,                      colour ]
	[ Stat.STAT.SWAG,    "Swag",    "res://Art/swag.png",    Color(0.95, 0.85, 0.20) ],
	[ Stat.STAT.GUTS,    "Guts",    "res://Art/guts.png",    Color(0.95, 0.35, 0.35) ],
	[ Stat.STAT.MARBLES, "Marbles", "res://Art/marbles.png", Color(0.30, 0.75, 1.00) ],
	[ Stat.STAT.HUSTLE,  "Hustle",  "res://Art/hustle.png",  Color(0.40, 0.90, 0.40) ],
	[ Stat.STAT.BANG,    "Bang",    "res://Art/bang.png",    Color(1.00, 0.60, 0.10) ],
	[ Stat.STAT.MOJO,    "Mojo",    "res://Art/mojo.png",    Color(0.75, 0.35, 1.00) ],
]

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────

var _selected_data    : CharacterData = null
var _card_nodes       : Array         = []

# ─────────────────────────────────────────────────────────────────────────────
#  BUILT NODES  (detail panel)
# ─────────────────────────────────────────────────────────────────────────────

var _detail_panel      : PanelContainer
var _detail_portrait   : TextureRect
var _detail_name       : Label
var _detail_hp_bar     : ProgressBar
var _detail_hp_label   : Label
var _detail_hp_formula : Label
var _detail_stat_rows  : Dictionary
var _detail_effects    : HFlowContainer  # ConditionIcon row
var _begin_btn         : Button
var _placeholder_lbl   : Label
var _card_list         : HBoxContainer

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()

# ─────────────────────────────────────────────────────────────────────────────
#  BUILD UI
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.10)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left   =  24.0
	root_vbox.offset_top    =  20.0
	root_vbox.offset_right  = -24.0
	root_vbox.offset_bottom = -20.0
	root_vbox.add_theme_constant_override("separation", 16)
	add_child(root_vbox)

	_build_top_panel(root_vbox)
	_build_bottom_panel(root_vbox)
	_populate_character_list()

# ── TOP: character sheet detail ───────────────────────────────────────────────

func _build_top_panel(parent: Control) -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 1.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.border_color = Color(0.30, 0.30, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_detail_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(_detail_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 14)
	_detail_panel.add_child(outer_vbox)

	_placeholder_lbl = Label.new()
	_placeholder_lbl.text = "↓ Select a character below to preview"
	_placeholder_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_placeholder_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_placeholder_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	_placeholder_lbl.add_theme_font_size_override("font_size", 16)
	outer_vbox.add_child(_placeholder_lbl)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	content_vbox.visible = false
	outer_vbox.add_child(content_vbox)
	outer_vbox.set_meta("content_ref", content_vbox)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(main_hbox)

	_detail_portrait = TextureRect.new()
	_detail_portrait.custom_minimum_size   = Vector2(120, 120)
	_detail_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_portrait.expand_mode  = TextureRect.EXPAND_FIT_HEIGHT
	main_hbox.add_child(_detail_portrait)

	main_hbox.add_child(VSeparator.new())

	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(mid_vbox)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.clip_contents = true
	mid_vbox.add_child(_detail_name)

	var hp_section := VBoxContainer.new()
	hp_section.add_theme_constant_override("separation", 3)
	mid_vbox.add_child(hp_section)

	var hp_title := Label.new()
	hp_title.text = "Health"
	hp_title.add_theme_font_size_override("font_size", 11)
	hp_title.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	hp_section.add_child(hp_title)

	_detail_hp_bar = ProgressBar.new()
	_detail_hp_bar.custom_minimum_size = Vector2(0, 16)
	_detail_hp_bar.show_percentage     = false
	hp_section.add_child(_detail_hp_bar)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_section.add_child(hp_row)

	_detail_hp_label = Label.new()
	_detail_hp_label.add_theme_font_size_override("font_size", 12)
	hp_row.add_child(_detail_hp_label)

	_detail_hp_formula = Label.new()
	_detail_hp_formula.add_theme_font_size_override("font_size", 11)
	_detail_hp_formula.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	_detail_hp_formula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_hp_formula.clip_contents = true
	hp_row.add_child(_detail_hp_formula)

	mid_vbox.add_child(HSeparator.new())

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 5)
	mid_vbox.add_child(stats_grid)

	_detail_stat_rows = {}
	for meta in STAT_META:
		var stat_type : int    = meta[0]
		var stat_name : String = meta[1]
		var icon_path : String = meta[2]
		var col       : Color  = meta[3]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		stats_grid.add_child(row)

		var icon := TextureRect.new()
		icon.texture             = load(icon_path)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		row.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = "%s:" % stat_name
		name_lbl.custom_minimum_size = Vector2(52, 0)
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "–"
		val_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(val_lbl)

		_detail_stat_rows[stat_type] = val_lbl

	main_hbox.add_child(VSeparator.new())

	# Right column — special effects as ConditionIcons
	var fx_vbox := VBoxContainer.new()
	fx_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fx_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(fx_vbox)

	var fx_title := Label.new()
	fx_title.text = "Special"
	fx_title.add_theme_font_size_override("font_size", 13)
	fx_title.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	fx_vbox.add_child(fx_title)

	_detail_effects = HFlowContainer.new()
	_detail_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_effects.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_detail_effects.add_theme_constant_override("h_separation", 4)
	_detail_effects.add_theme_constant_override("v_separation", 4)
	fx_vbox.add_child(_detail_effects)

	content_vbox.add_child(HSeparator.new())

	_begin_btn = Button.new()
	_begin_btn.text    = "Begin Run"
	_begin_btn.visible = false
	_begin_btn.add_theme_font_size_override("font_size", 16)
	_begin_btn.pressed.connect(_on_begin_run_pressed)
	content_vbox.add_child(_begin_btn)

# ── BOTTOM: scrollable horizontal character card row ──────────────────────────

func _build_bottom_panel(parent: Control) -> void:
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	bottom_vbox.size_flags_stretch_ratio = 1.0
	bottom_vbox.add_theme_constant_override("separation", 8)
	parent.add_child(bottom_vbox)

	var title := Label.new()
	title.text = "Choose Your Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	bottom_vbox.add_child(title)

	bottom_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical        = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode       = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode     = ScrollContainer.SCROLL_MODE_AUTO
	bottom_vbox.add_child(scroll)

	_card_list = HBoxContainer.new()
	_card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_list.alignment           = BoxContainer.ALIGNMENT_CENTER
	_card_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_card_list)

# ─────────────────────────────────────────────────────────────────────────────
#  POPULATE CHARACTER LIST
# ─────────────────────────────────────────────────────────────────────────────

func _populate_character_list() -> void:
	_card_nodes.clear()

	if characters.is_empty():
		var warn := Label.new()
		warn.text          = "No characters assigned.\nAdd CharacterData in the Inspector."
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Color(0.80, 0.40, 0.40))
		_card_list.add_child(warn)
		return

	for char_data in characters:
		var preview := _make_preview_character(char_data)
		var resolved : Dictionary = {}
		for meta in STAT_META:
			resolved[meta[0]] = _get_stat_value_from_character(preview, meta[0])
		preview.queue_free()

		var card := _build_character_card(char_data, resolved)
		_card_list.add_child(card)
		_card_nodes.append(card)

# ─────────────────────────────────────────────────────────────────────────────
#  CHARACTER CARD  (left panel)
# ─────────────────────────────────────────────────────────────────────────────

func _build_character_card(char_data: CharacterData, resolved_stats: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(90, 90)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.set_meta("char_data", char_data)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.18)
	style_normal.border_color = Color(0.28, 0.28, 0.32)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(5)
	style_normal.set_content_margin_all(5)
	card.add_theme_stylebox_override("panel", style_normal)
	card.set_meta("style_normal", style_normal)

	var style_selected := StyleBoxFlat.new()
	style_selected.bg_color     = Color(0.18, 0.22, 0.30)
	style_selected.border_color = Color(0.50, 0.75, 1.00)
	style_selected.set_border_width_all(2)
	style_selected.set_corner_radius_all(5)
	style_selected.set_content_margin_all(5)
	card.set_meta("style_selected", style_selected)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(70, 70)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.texture      = char_data.character_image
	vbox.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = char_data.character_name if char_data.character_name != "" else "Unnamed"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_contents        = true
	name_lbl.custom_minimum_size  = Vector2(0, 14)
	name_lbl.size_flags_vertical  = Control.SIZE_SHRINK_END
	name_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(name_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.anchor_right  = 1.0
	btn.anchor_bottom = 1.0
	btn.focus_mode    = Control.FOCUS_NONE
	var flat_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, flat_style)
	btn.pressed.connect(_on_character_card_pressed.bind(char_data, card))
	card.add_child(btn)

	return card

# ─────────────────────────────────────────────────────────────────────────────
#  SELECTION
# ─────────────────────────────────────────────────────────────────────────────

func _on_character_card_pressed(char_data: CharacterData, pressed_card: PanelContainer) -> void:
	_selected_data = char_data

	for card in _card_nodes:
		if card == pressed_card:
			card.add_theme_stylebox_override("panel", card.get_meta("style_selected"))
		else:
			card.add_theme_stylebox_override("panel", card.get_meta("style_normal"))

	_refresh_detail_panel(char_data)

func _refresh_detail_panel(char_data: CharacterData) -> void:
	_placeholder_lbl.visible = false

	var outer_vbox : VBoxContainer = _detail_panel.get_child(0)
	var content_vbox : VBoxContainer = outer_vbox.get_meta("content_ref")
	content_vbox.visible = true

	var preview := _make_preview_character(char_data)

	_detail_portrait.texture = char_data.character_image
	_detail_name.text = char_data.character_name if char_data.character_name != "" else "Unnamed"

	var max_hp  : int = char_data.max_health.calculate(preview) if char_data.max_health else 100
	var cur_hp  : int = max_hp
	_detail_hp_bar.visible   = true
	_detail_hp_bar.max_value = max_hp
	_detail_hp_bar.value     = cur_hp
	_detail_hp_label.text    = "%d / %d" % [cur_hp, max_hp]
	if char_data.max_health and char_data.max_health.formula != "":
		_detail_hp_formula.text = "( %s )" % char_data.max_health.formula
	else:
		_detail_hp_formula.text = ""

	for meta in STAT_META:
		var stat_type : int = meta[0]
		var val : int = _get_stat_value_from_character(preview, stat_type)
		if _detail_stat_rows.has(stat_type):
			_detail_stat_rows[stat_type].text = str(val)

	preview.queue_free()

	# Special effects — rebuild ConditionIcon row
	for child in _detail_effects.get_children():
		child.queue_free()

	for fx in char_data.special_effects:
		if fx is Condition:
			var icon := ConditionIcon.new(fx)
			_detail_effects.add_child(icon)
			icon.ready.connect(icon.update_display.bind(), CONNECT_ONE_SHOT)

	_begin_btn.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  BEGIN RUN
# ─────────────────────────────────────────────────────────────────────────────

func _on_begin_run_pressed() -> void:
	if not _selected_data:
		return

	if not run_manager_scene:
		push_error("CharacterSelect: run_manager_scene is not assigned in the Inspector!")
		return

	var preview := _make_preview_character(_selected_data)
	_selected_data.current_health = _selected_data.max_health.calculate(preview) if _selected_data.max_health else 100
	preview.queue_free()

	var run_manager : RunManager = run_manager_scene.instantiate()
	run_manager.character = _selected_data
	get_tree().root.add_child(run_manager)
	queue_free()

# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _get_stat_value(char_data: CharacterData, stat_type: int) -> int:
	for s in char_data.stats:
		if s.stat_type == stat_type:
			return s.value
	return 0

func _get_stat_value_from_character(character: Character, stat_type: int) -> int:
	for s in character.stats:
		if s.stat_type == stat_type:
			return s.value
	return 0

func _make_preview_character(char_data: CharacterData) -> Character:
	var character : Character = load("res://Scenes/character.tscn").instantiate()
	add_child(character)
	character.set_data(char_data)
	return character
