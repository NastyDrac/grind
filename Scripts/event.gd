extends CanvasLayer
class_name EventScene

var run_manager: RunManager
var current_event: EventData

# UI references - assign these to the nodes in the scene
@onready var title_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/Title"
@onready var description_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/description"
@onready var event_image: TextureRect = $"EventMargin#Panel/EventMargin#VBoxContainer/EventImage"
@onready var options_container: VBoxContainer = $"EventMargin#Panel/EventMargin#VBoxContainer/options container"

# Signals
signal option_selected(option: EventOption)
signal event_completed

func _ready():
	if current_event:
		display_event(current_event)

func display_event(event: EventData):
	current_event = event
	
	# Set title
	if title_label:
		title_label.text = event.event_title
	
	# Set description
	if description_label:
		description_label.text = event.event_description
	
	# Set image (if available)
	if event_image and event.event_image:
		event_image.texture = event.event_image
		event_image.visible = true
	elif event_image:
		event_image.visible = false
	
	# Clear existing option buttons
	if options_container:
		for child in options_container.get_children():
			child.queue_free()
	
	# Create buttons for each option
	for option in event.options:
		_create_option_button(option)

func _create_option_button(option: EventOption):
	var button = Button.new()
	button.text = option.option_text
	button.custom_minimum_size = Vector2(400, 60)
	
	# Check if option can be selected
	var can_select = option.can_select(run_manager.character.gold, run_manager.deck)
	button.disabled = not can_select
	
	# Add tooltip if option is disabled
	if not can_select:
		button.tooltip_text = option.get_unavailable_reason(run_manager.character.gold, run_manager.deck)
	
	# Style the button (you can customize this)
	button.add_theme_font_size_override("font_size", 20)
	
	# Connect the button signal
	button.pressed.connect(_on_option_selected.bind(option))
	
	options_container.add_child(button)

func _on_option_selected(option: EventOption):
	# Emit signal
	option_selected.emit(option)
	
	# Process the option results
	_process_option_results(option)
	
	# Show result text (optional - you might want a separate result screen)
	if option.result_text and option.result_text != "":
		_show_result(option)
	else:
		_finish_event(option)

func _show_result(option: EventOption):
	# Clear options
	for child in options_container.get_children():
		child.queue_free()
	
	# Show result text
	description_label.text = option.result_text
	
	# Create continue button
	var continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(200, 60)
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.pressed.connect(_finish_event.bind(option))
	
	options_container.add_child(continue_button)

func _process_option_results(option: EventOption):
	if not run_manager:
		push_error("EventScene requires a run_manager reference")
		return
	
	# Apply gold changes
	if option.gold_cost > 0:
		run_manager.gold -= option.gold_cost
	if option.gold_reward > 0:
		run_manager.character.gold += option.gold_reward
	
	# Apply health changes
	if option.health_change != 0:
		run_manager.character.current_health += option.health_change
		# Clamp health
		run_manager.character.current_health = clamp(
			run_manager.character.current_health,
			0,
			run_manager.character.max_health
		)
	
	# Add cards to deck
	for card in option.cards_to_add:
		run_manager.deck.append(card)
	
	# Remove cards from deck
	for card in option.cards_to_remove:
		run_manager.deck.erase(card)

func _finish_event(option: EventOption):
	# Check if this triggers combat
	if option.triggers_combat:
		_start_combat(option)
	else:
		# No combat - just continue
		event_completed.emit()
		queue_free()

func _start_combat(option: EventOption):
	# Set up the horde for combat
	if option.combat_horde.size() > 0:
		run_manager.horde = option.combat_horde.duplicate()
	
	# Apply difficulty modifier
	run_manager.initial_enemy_count = int(run_manager.initial_enemy_count * option.combat_difficulty_modifier)
	
	# Emit event completed and let run_manager handle starting combat
	event_completed.emit()
	queue_free()
	
	# The run_manager should call begin_wave() after this
