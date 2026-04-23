extends CanvasLayer
class_name DeckViewer

## Self-contained card viewer / picker overlay.
##
## Usage:
##   var viewer := DeckViewer.new()
##   add_child(viewer)
##   viewer.setup("Choose a card", cards, DeckViewer.Mode.SELECT, "Pick one to remove:")
##   viewer.card_selected.connect(_on_card_chosen)   # SELECT mode
##   viewer.closed.connect(_on_viewer_closed)         # either mode


enum Mode {
	DISPLAY,  ## Read-only. Backdrop click or Close button dismisses.
	SELECT,   ## Player clicks a card to confirm. Emits card_selected then closes.
}

signal card_selected(card_data: CardData)
signal closed

const _DRAFTABLE_CARD = preload("res://Scenes/draftable_card.tscn")

var _mode: Mode = Mode.DISPLAY


func setup(title_text: String, cards: Array[CardData], mode: Mode, prompt: String = "") -> void:
	_mode = mode
	layer = 100
	_build_ui(title_text, cards, prompt)


func _build_ui(title_text: String, cards: Array[CardData], prompt: String) -> void:
	# ── Backdrop ──────────────────────────────────────────────────────────────
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if _mode == Mode.DISPLAY:
		backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# ── Panel ─────────────────────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1050, 600)
	panel.offset_left   = -525
	panel.offset_top    = -275
	panel.offset_right  =  500
	panel.offset_bottom =  275
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# ── Title bar ─────────────────────────────────────────────────────────────
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕  Close" if _mode == Mode.DISPLAY else "Skip"
	close_btn.pressed.connect(_close)
	title_bar.add_child(close_btn)

	# ── Prompt (SELECT mode only) ──────────────────────────────────────────────
	if prompt != "":
		var prompt_lbl := Label.new()
		prompt_lbl.text = prompt
		prompt_lbl.add_theme_font_size_override("font_size", 16)
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(prompt_lbl)

	# ── Scrollable card grid ───────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	#var flow := HFlowContainer.new()
	#flow.add_theme_constant_override("h_separation", 20)
	#flow.add_theme_constant_override("v_separation", 20)
	#flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#scroll.add_child(flow)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	if cards.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "( empty )"
		empty_lbl.add_theme_font_size_override("font_size", 18)
		grid.add_child(empty_lbl)
		return

	for card_data in cards:
		var draftable: DraftableCard = _DRAFTABLE_CARD.instantiate()
		grid.add_child(draftable)
		draftable.current_mode = DraftableCard.Mode.DISPLAY_ONLY
		draftable.set_data(card_data)
		if _mode == Mode.SELECT:
			draftable.card_selected.connect(_on_card_selected)


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_card_selected(card_data: CardData) -> void:
	card_selected.emit(card_data)
	_close()


func _on_backdrop_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
