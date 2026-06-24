extends CanvasLayer
class_name EventScene

var run_manager: RunManager
var current_event: EventData
var current_option: EventOption


@onready var title_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/Title"
@onready var description_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/description"
@onready var event_image: TextureRect = $"EventMargin#Panel/EventMargin#VBoxContainer/EventImage"
@onready var options_container: VBoxContainer = $"EventMargin#Panel/EventMargin#VBoxContainer/options container"


var _effect_queue: Array[EventEffect] = []

## Hover preview: a copy of a card an option would add, shown while hovering.
const _CARD_PREVIEW_SCENE := preload("res://Scenes/draftable_card.tscn")
var _card_preview : DraftableCard = null


signal option_selected(option: EventOption)
signal event_completed


func _ready():
	if current_event:
		display_event(current_event)


func display_event(event: EventData):
	current_event = event

	if title_label:
		title_label.text = event.event_title
	if description_label:
		description_label.text = event.event_description
	if event_image and event.event_image:
		event_image.texture = event.event_image
		event_image.visible = true
	elif event_image:
		event_image.visible = false

	if options_container:
		_hide_card_preview()
		for child in options_container.get_children():
			child.queue_free()

	for option in event.options:
		_create_option_button(option)


func _create_option_button(option: EventOption):
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(400, 60)

	var can_select := option.can_select(run_manager.character.gold, run_manager.deck)
	button.disabled = not can_select
	if not can_select:
		button.tooltip_text = option.get_unavailable_reason(run_manager.character.gold, run_manager.deck)

	#button.add_theme_font_size_override("font_size", 20)
	
	# Use an HBoxContainer to hold the option text and effect text as separate Labels
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var option_label := Label.new()
	option_label.text = option.option_text + ". "
	option_label.add_theme_font_size_override("font_size", 20)
	option_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(option_label)

	var effects_text := ""
	for each in option.effects:
		effects_text += each.get_description(run_manager)

	if effects_text != "":
		var effect_label := Label.new()
		effect_label.text = effects_text
		effect_label.add_theme_font_size_override("font_size", 20)
		effect_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0)) # Light blue — change as needed
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(effect_label)

	button.add_child(hbox)
	button.pressed.connect(_on_option_selected.bind(option))

	# Hover extras: a card copy for add-card effects, a text tooltip for relics.
	var preview_card : CardData = null
	var tip_text := ""
	for each in option.effects:
		if preview_card == null:
			preview_card = each.get_preview_card()
		var t = each.get_tooltip_text()
		if t != "":
			tip_text += (("\n" + t) if tip_text != "" else t)
	if can_select and tip_text != "":
		button.tooltip_text = tip_text   # disabled buttons keep their reason text
	if preview_card != null:
		button.mouse_entered.connect(_show_card_preview.bind(preview_card, button))
		button.mouse_exited.connect(_hide_card_preview)

	options_container.add_child(button)


func _on_option_selected(option: EventOption):
	current_option = option
	option_selected.emit(option)
	_hide_card_preview()

	# Telemetry: which event and which option the player chose.
	Global.event_option_chosen.emit(
		current_event.event_title if current_event else "", option.option_text)

	if option.gold_cost > 0:
		run_manager.character.gold -= option.gold_cost
		run_manager.ui_bar.set_gold()

	_effect_queue = option.effects.duplicate()
	_process_next_effect()


# ── Hover card preview ────────────────────────────────────────────────────────

## Show a DISPLAY_ONLY copy of [card_data] next to [anchor] (the option button).
func _show_card_preview(card_data: CardData, anchor: Control) -> void:
	_hide_card_preview()
	if card_data == null:
		return

	var preview : DraftableCard = _CARD_PREVIEW_SCENE.instantiate()
	add_child(preview)                                   # enters tree → @onready ready
	preview.current_mode = DraftableCard.Mode.DISPLAY_ONLY
	preview.set_data(card_data)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never steal the hover
	preview.top_level = true                             # position in global space
	preview.z_index = 100
	preview.scale = Vector2(0.85, 0.85)
	_card_preview = preview

	# Wait one frame so the card has a real size, then place it beside the button,
	# flipping to the left side if it would run off the right edge.
	await get_tree().process_frame
	if not is_instance_valid(preview) or _card_preview != preview:
		return
	var vp := get_viewport().get_visible_rect().size
	var card_size : Vector2 = preview.size * preview.scale
	var pos := anchor.global_position + Vector2(anchor.size.x + 16, anchor.size.y * 0.5 - card_size.y * 0.5)
	if pos.x + card_size.x > vp.x:
		pos.x = anchor.global_position.x - card_size.x - 16
	pos.x = maxf(8.0, pos.x)
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - card_size.y - 8.0))
	preview.global_position = pos


func _hide_card_preview() -> void:
	if is_instance_valid(_card_preview):
		_card_preview.queue_free()
	_card_preview = null


# ==== EFFECT QUEUE ============================================================

func _process_next_effect() -> void:
	if _effect_queue.is_empty():
		_on_all_effects_done()
		return

	var effect: EventEffect = _effect_queue.pop_front()
	effect.execute(run_manager, self, _process_next_effect)


func _on_all_effects_done() -> void:
	if current_option.result_text and current_option.result_text != "":
		_show_result(current_option)
	else:
		_finish_event(current_option)


# ==== RESULT / FINISH =========================================================

func _show_result(option: EventOption):
	for child in options_container.get_children():
		child.queue_free()

	description_label.text = option.result_text

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(200, 60)
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.pressed.connect(_finish_event.bind(option))
	options_container.add_child(continue_button)


func _finish_event(option: EventOption):
	if option.triggers_combat:
		_start_combat(option)
	else:
		event_completed.emit()
		queue_free()


func _start_combat(option: EventOption):
	if option.combat_horde == null:
		push_warning("EventOption.triggers_combat is on but combat_horde is null; skipping combat.")
		event_completed.emit()
		queue_free()
		return

	# Hand the fight to the RunManager, which launches it once this scene closes
	# (see RunManager._on_event_completed). get_spawn_pool() is read there off the
	# Horde, so the Array[HordeEnemy] / Array[EnemyData] mismatch is gone.
	run_manager.queue_event_combat(option.combat_horde, option.combat_difficulty_modifier, option.win_con)
	event_completed.emit()
	queue_free()
