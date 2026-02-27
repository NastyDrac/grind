extends CanvasLayer
class_name Services

# ─── Layout ───────────────────────────────────────────────────────────────────
const UIBAR_HEIGHT : float = 50.0
const MARGIN       : float = 40.0

# ─── State ────────────────────────────────────────────────────────────────────
var run : RunManager

# ─── Built nodes ──────────────────────────────────────────────────────────────
var gold_label       : Label
var choice_container : HBoxContainer

signal service_chosen(service: String)

# ─── Service definitions ──────────────────────────────────────────────────────
# [id, title, icon_char, color, description]
const SERVICES_LIST : Array = [
	[
		"hospital",
		"Hospital",
		"➕",
		Color(0.20, 0.85, 0.50),
		"Restore lost health.\nThe doc has a few\noptions for ya."
	],
	[
		"gym",
		"Gym",
		"💪",
		Color(0.95, 0.60, 0.15),
		"Train hard, get\npermanent stat\nboosts. Pick one."
	],
	[
		"shop",
		"Shop",
		"🛒",
		Color(0.95, 0.85, 0.20),
		"Browse cards and\nthingies. Spend\nyour hard-earned gold."
	],
]

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
	title_lbl.text = "Services"
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

	var sub_lbl := Label.new()
	sub_lbl.text = "Where would you like to go?"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	root_vbox.add_child(sub_lbl)

	root_vbox.add_child(HSeparator.new())

	# ── Vertically centred choice row ──
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer_top)

	choice_container = HBoxContainer.new()
	choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_container.add_theme_constant_override("separation", 32)
	root_vbox.add_child(choice_container)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer_bot)

# ─── Public entry point ───────────────────────────────────────────────────────

func display_services(run_manager: RunManager) -> void:
	run = run_manager
	_refresh_gold()
	_populate_choices()

# ─── Populate ─────────────────────────────────────────────────────────────────

func _populate_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

	for svc in SERVICES_LIST:
		choice_container.add_child(
			_build_service_card(svc[0], svc[1], svc[2], svc[3], svc[4])
		)

func _build_service_card(
		id    : String,
		title : String,
		icon  : String,
		col   : Color,
		desc  : String) -> PanelContainer:

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 220)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(col.r, col.g, col.b, 0.08)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# ── Big icon ──
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 40)
	vbox.add_child(icon_lbl)

	# ── Title ──
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", col)
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	# ── Description ──
	var desc_lbl := Label.new()
	desc_lbl.text          = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(desc_lbl)

	# ── Visit button ──
	var btn := Button.new()
	btn.text = "Visit %s" % title
	btn.pressed.connect(_on_service_chosen.bind(id))
	vbox.add_child(btn)

	return card

# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_service_chosen(id: String) -> void:
	service_chosen.emit(id)

func _on_leave_pressed() -> void:
	run.close_services()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _refresh_gold() -> void:
	if run and run.character:
		gold_label.text = "Gold: %d" % run.character.gold
