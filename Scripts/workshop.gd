extends CanvasLayer
class_name Workshop

# ─── Configuration ─────────────────────────────────────────────────────────────
## How many cards the player may retune in one visit.
@export var restats_per_visit : int = 1

# The six stats, in display order: [formula_token, display_name].
const STAT_OPTIONS : Array = [
	["swag", "Swag"], ["marbles", "Marbles"], ["guts", "Guts"],
	["heat", "Heat"], ["hustle", "Hustle"], ["mojo", "Mojo"],
]

# Which calculators count as the card's "value" (editable). Excludes utility
# calcs like push distance, draw count, and target count.
const VALUE_CALC_PROPS : Array = [
	"damage_calculator", "block_calculator", "stacks_calculator", "modify_calculator",
]

const _DRAFTABLE_CARD = preload("res://Scenes/draftable_card.tscn")

# ─── State ────────────────────────────────────────────────────────────────────
var run : RunManager
var _restats_left : int = 0

# Picker working state
var _picker         : Control = null
var _picker_content : VBoxContainer = null
var _picker_card    : CardData = null
var _picker_calc    : ValueCalculator = null

# ─── Built nodes ──────────────────────────────────────────────────────────────
var grid        : GridContainer
var retunes_lbl : Label

signal workshop_closed

# ─── Build the UI ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 1
	_build_shell()

func _build_shell() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1050, 620)
	panel.offset_left   = -525
	panel.offset_top    = -310
	panel.offset_right  =  525
	panel.offset_bottom =  310
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = "Workshop"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	retunes_lbl = Label.new()
	retunes_lbl.add_theme_font_size_override("font_size", 14)
	retunes_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	title_bar.add_child(retunes_lbl)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.pressed.connect(_on_leave_pressed)
	title_bar.add_child(leave_btn)

	var prompt := Label.new()
	prompt.text = "Select a card to retune."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prompt)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

# ─── Public entry point ───────────────────────────────────────────────────────

func display_workshop(run_manager: RunManager) -> void:
	run = run_manager
	_restats_left = max(1, restats_per_visit)
	_update_retunes_label()
	_populate_deck()

# ─── Deck grid ─────────────────────────────────────────────────────────────────

func _populate_deck() -> void:
	for child in grid.get_children():
		child.queue_free()

	if not run or run.deck == null:
		return

	for card in run.deck:
		if card.modified:
			continue  # already retuned once — no second modification
		if _primary_value_calc(card) == null:
			continue  # no editable value — don't show it

		var dc: DraftableCard = _DRAFTABLE_CARD.instantiate()
		grid.add_child(dc)
		dc.current_mode = DraftableCard.Mode.DISPLAY_ONLY
		dc.set_data(card)
		dc.card_selected.connect(_on_card_picked)

# ─── Picker: phase 1 (choose a term) ────────────────────────────────────────────

func _on_card_picked(card: CardData) -> void:
	_picker_card = card
	_picker_calc = _primary_value_calc(card)
	if _picker_calc == null:
		return
	_open_picker()
	_show_term_phase()

func _open_picker() -> void:
	_close_picker()

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(_on_picker_backdrop_input)
	overlay.add_child(back)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(440, 380)
	panel.offset_left   = -220
	panel.offset_top    = -190
	panel.offset_right  =  220
	panel.offset_bottom =  190
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	_picker_content = VBoxContainer.new()
	_picker_content.add_theme_constant_override("separation", 10)
	_picker_content.offset_left = 16
	_picker_content.offset_top = 14
	_picker_content.offset_right = -16
	_picker_content.offset_bottom = -14
	panel.add_child(_picker_content)

	add_child(overlay)
	_picker = overlay

func _show_term_phase() -> void:
	_clear_picker_content()

	var name_lbl := Label.new()
	name_lbl.text = _picker_card.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	_picker_content.add_child(name_lbl)

	var formula_lbl := Label.new()
	formula_lbl.text = "%s  =  %d" % [_picker_calc.formula, _picker_calc.calculate(run.player)]
	formula_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula_lbl.add_theme_font_size_override("font_size", 14)
	formula_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	_picker_content.add_child(formula_lbl)

	var hint := Label.new()
	hint.text = "Choose a value to change:"
	hint.add_theme_font_size_override("font_size", 14)
	_picker_content.add_child(hint)

	var term_box := HBoxContainer.new()
	term_box.alignment = BoxContainer.ALIGNMENT_CENTER
	term_box.add_theme_constant_override("separation", 8)
	_picker_content.add_child(term_box)

	var tokens = _picker_calc.value_tokens()
	for i in tokens.size():
		var btn := Button.new()
		btn.text = str(tokens[i].text).capitalize()
		btn.pressed.connect(_show_stat_phase.bind(i))
		term_box.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_picker)
	_picker_content.add_child(cancel)

# ─── Picker: phase 2 (choose the new stat) ───────────────────────────────────────

func _show_stat_phase(token_index: int) -> void:
	_clear_picker_content()

	var tokens = _picker_calc.value_tokens()
	var term_text : String = str(tokens[token_index].text)

	var title := Label.new()
	title.text = "Change \"%s\" to:" % term_text.capitalize()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_picker_content.add_child(title)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 10)
	stat_grid.add_theme_constant_override("v_separation", 8)
	_picker_content.add_child(stat_grid)

	for opt in STAT_OPTIONS:
		var token : String = opt[0]
		var display : String = opt[1]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if token == term_text:
			btn.text = "%s  (current)" % display
			btn.disabled = true
		else:
			btn.text = "%s   (→ %d)" % [display, _preview(token_index, token)]
			btn.pressed.connect(_apply_retune.bind(token_index, token))
		stat_grid.add_child(btn)

	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_show_term_phase)
	_picker_content.add_child(back)

# ─── Apply ──────────────────────────────────────────────────────────────────────

func _apply_retune(token_index: int, target: String) -> void:
	# Telemetry: capture the before→after term BEFORE retune_token mutates it.
	var _old_term : String = str(_picker_calc.value_tokens()[token_index].text)
	Global.card_workshopped.emit(_picker_card.card_name, "%s→%s" % [_old_term, target])

	_picker_calc.retune_token(token_index, target)
	_picker_card.modified = true
	_close_picker()
	_restats_left -= 1

	if _restats_left <= 0:
		_close()
		return

	_update_retunes_label()
	_populate_deck()

# ─── Picker lifecycle ───────────────────────────────────────────────────────────

func _clear_picker_content() -> void:
	for child in _picker_content.get_children():
		child.queue_free()

func _close_picker() -> void:
	if _picker and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null
	_picker_content = null

func _on_picker_backdrop_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_close_picker()

# ─── Close ────────────────────────────────────────────────────────────────────

func _on_leave_pressed() -> void:
	_close()

func _close() -> void:
	workshop_closed.emit()

# ─── Helpers ──────────────────────────────────────────────────────────────────

## The card's primary editable value calculator (damage/block/stacks/modify),
## or null if the card has no editable value. Found in action order.
func _primary_value_calc(card: CardData) -> ValueCalculator:
	if card == null:
		return null
	for action in card.actions:
		if action == null:
			continue
		for prop_name in VALUE_CALC_PROPS:
			var v = action.get(prop_name)
			if typeof(v) == TYPE_OBJECT and is_instance_valid(v) and v is ValueCalculator:
				return v
	return null

## Resulting value if the given term were swapped to `target`, without
## mutating the real card.
func _preview(token_index: int, target: String) -> int:
	var tmp := ValueCalculator.new()
	tmp.formula = _picker_calc.formula
	tmp.retune_token(token_index, target)
	return tmp.calculate(run.player)

func _update_retunes_label() -> void:
	retunes_lbl.text = "Retunes left: %d" % _restats_left
