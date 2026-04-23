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
	options_container.add_child(button)


func _on_option_selected(option: EventOption):
	current_option = option
	option_selected.emit(option)

	if option.gold_cost > 0:
		run_manager.character.gold -= option.gold_cost
		run_manager.ui_bar.set_gold()

	_effect_queue = option.effects.duplicate()
	_process_next_effect()


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
	if option.combat_horde.size() > 0:
		run_manager.horde = option.combat_horde.duplicate()
	if option.win_con:
		run_manager.win_condition = option.win_con
	run_manager.initial_enemy_count = int(run_manager.initial_enemy_count * option.combat_difficulty_modifier)
	event_completed.emit()
	queue_free()
