extends MarginContainer
class_name CharacterSelect

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────────────────────────────────────

## Assign all playable CharacterData resources here in the Inspector.
@export var characters : Array[CharacterData] = []

## Path to your RunManager scene.
@export var run_manager_scene : PackedScene

# ─────────────────────────────────────────────────────────────────────────────
#  SCENE NODE REFERENCES
#  Wire each of these to the matching node in your scene in the Inspector.
# ─────────────────────────────────────────────────────────────────────────────

@export_category("Detail Panel")
## The label shown before any character is selected.
@export var placeholder_label    : Label
## Parent node shown/hidden as a group once a character is selected.
@export var detail_content       : Control
@export var detail_portrait      : TextureRect
@export var detail_name          : Label
@export var detail_hp_bar        : ProgressBar
@export var detail_hp_label      : Label
@export var detail_hp_formula    : Label
## HFlowContainer that holds the ConditionIcon nodes for special effects.
@export var detail_effects       : HFlowContainer
@export var begin_button         : Button

@export_category("Character List")
## HBoxContainer (inside a ScrollContainer) where character cards are spawned.
@export var card_list            : HBoxContainer

@export_category("Stat Labels")
## One Label per stat for the detail panel readouts.
## Order: Swag, Guts, Marbles, Hustle, Bang, Mojo.
@export var stat_label_swag    : Label
@export var stat_label_guts    : Label
@export var stat_label_marbles : Label
@export var stat_label_hustle  : Label
@export var stat_label_bang    : Label
@export var stat_label_mojo    : Label
@export var gold_label         : Label

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
var _detail_stat_rows : Dictionary    = {}

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if begin_button:
		begin_button.visible = false
		begin_button.pressed.connect(_on_begin_run_pressed)

	if detail_content:
		detail_content.visible = false

	if placeholder_label:
		placeholder_label.visible = true

	_build_stat_rows()
	_populate_character_list()
	_selected_data = characters[0]
	_refresh_detail_panel(characters[0])

# ─────────────────────────────────────────────────────────────────────────────
#  STAT ROWS  — map enum values to the exported Label nodes
# ─────────────────────────────────────────────────────────────────────────────

func _build_stat_rows() -> void:
	var labels := [
		stat_label_swag,
		stat_label_guts,
		stat_label_marbles,
		stat_label_hustle,
		stat_label_bang,
		stat_label_mojo,
	]
	for i in STAT_META.size():
		var stat_type : int = STAT_META[i][0]
		if labels[i] != null:
			_detail_stat_rows[stat_type] = labels[i]

# ─────────────────────────────────────────────────────────────────────────────
#  POPULATE CHARACTER LIST
# ─────────────────────────────────────────────────────────────────────────────

func _populate_character_list() -> void:
	_card_nodes.clear()

	if not card_list:
		push_warning("CharacterSelect: card_list node is not assigned!")
		return

	if characters.is_empty():
		var warn := Label.new()
		warn.text          = "No characters assigned.\nAdd CharacterData in the Inspector."
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Color(0.80, 0.40, 0.40))
		card_list.add_child(warn)
		return

	for char_data in characters:
		var preview := _make_preview_character(char_data)
		var resolved : Dictionary = {}
		for meta in STAT_META:
			resolved[meta[0]] = _get_stat_value_from_character(preview, meta[0])
		preview.queue_free()

		var card := _build_character_card(char_data, resolved)
		card_list.add_child(card)
		_card_nodes.append(card)

# ─────────────────────────────────────────────────────────────────────────────
#  CHARACTER CARD  (bottom panel)
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
	if placeholder_label:
		placeholder_label.visible = false

	if detail_content:
		detail_content.visible = true

	var preview := _make_preview_character(char_data)

	if detail_portrait:
		detail_portrait.texture = char_data.character_image

	if detail_name:
		detail_name.text = char_data.character_name if char_data.character_name != "" else "Unnamed"

	var max_hp : int = char_data.max_health.calculate(preview) if char_data.max_health else 100
	var cur_hp : int = max_hp

	if detail_hp_bar:
		detail_hp_bar.visible   = true
		detail_hp_bar.max_value = max_hp
		detail_hp_bar.value     = cur_hp

	if detail_hp_label:
		detail_hp_label.text = "%d / %d" % [cur_hp, max_hp]

	if detail_hp_formula:
		if char_data.max_health and char_data.max_health.formula != "":
			detail_hp_formula.text = "( %s )" % char_data.max_health.formula
		else:
			detail_hp_formula.text = ""

	for meta in STAT_META:
		var stat_type : int = meta[0]
		var val : int = _get_stat_value_from_character(preview, stat_type)
		if _detail_stat_rows.has(stat_type):
			_detail_stat_rows[stat_type].text = str(val)

	preview.queue_free()

	# Special effects — rebuild ConditionIcon row
	if detail_effects:
		for child in detail_effects.get_children():
			child.queue_free()

		for fx in char_data.special_effects:
			if fx is Condition:
				var icon := ConditionIcon.new()
				icon.set_condition(fx)
				detail_effects.add_child(icon)
				icon.ready.connect(icon.update_display.bind(), CONNECT_ONE_SHOT)

	if gold_label:
		gold_label.text = get_gold(char_data)
	if begin_button:
		begin_button.visible = true

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

func get_gold(char_data : CharacterData) -> String:
	return str(char_data.gold)
