extends CanvasLayer
class_name EventScene

var run_manager: RunManager
var current_event: EventData
var current_option: EventOption  # Track which option triggered card selection

# UI references - assign these to the nodes in the scene
@onready var title_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/Title"
@onready var description_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/description"
@onready var event_image: TextureRect = $"EventMargin#Panel/EventMargin#VBoxContainer/EventImage"
@onready var options_container: VBoxContainer = $"EventMargin#Panel/EventMargin#VBoxContainer/options container"

# Card selection UI
var card_selection_container: HBoxContainer = null
var draftable_cards: Array[DraftableCard] = []
var selected_cards: Array[CardData] = []

# Track if we're waiting for draft screen
var waiting_for_draft: bool = false

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
	# Store the current option
	current_option = option
	
	# Emit signal
	option_selected.emit(option)
	
	# Process the option results (gold, health, etc.)
	_process_option_results(option)
	
	# If we're waiting for draft screen, don't continue yet
	if waiting_for_draft:
		return
	
	# Check if this option requires card selection
	if option.card_selection_type != EventOption.CardSelectionType.NONE:
		_show_card_selection(option)
	elif option.result_text and option.result_text != "":
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
		run_manager.character.gold -= option.gold_cost
	if option.gold_reward > 0:
		run_manager.character.gold += option.gold_reward
	run_manager.ui_bar.set_gold()
	
	# Apply health changes
	if option.health_change != 0:
		run_manager.character.current_health += option.health_change
		# Clamp health
		run_manager.character.current_health = clamp(
			run_manager.character.current_health,
			0,
			run_manager.character.max_health.calculate(run_manager.player)
		)
		run_manager.ui_bar.set_health()
	
	# Handle card additions
	if option.random_selection:
		# FIXED: Set flag and connect to draft completion signal
		waiting_for_draft = true
		
		# Hide event UI while draft screen is shown
		visible = false
		
		# Create draft screen
		run_manager.create_draft_screen()
		
		# Connect to draft completion signal
		if run_manager.current_draft_screen:
			run_manager.current_draft_screen.draft_completed.connect(_on_draft_completed)
	else:
		# Add cards directly
		for card in option.cards_to_add:
			run_manager.deck.append(card)
	
	# Remove cards from deck
	for card in option.cards_to_remove:
		run_manager.deck.erase(card)

func _on_draft_completed():
	"""Called when the draft screen finishes"""
	waiting_for_draft = false
	
	# Show event UI again
	visible = true
	
	# Disconnect the signal
	if run_manager.current_draft_screen:
		if run_manager.current_draft_screen.draft_completed.is_connected(_on_draft_completed):
			run_manager.current_draft_screen.draft_completed.disconnect(_on_draft_completed)
	
	# Now continue with the event flow
	if current_option.result_text and current_option.result_text != "":
		_show_result(current_option)
	else:
		_finish_event(current_option)

# ==== CARD SELECTION METHODS ====

func _show_card_selection(option: EventOption):
	"""Display card selection interface based on option type"""
	# Clear options
	for child in options_container.get_children():
		child.queue_free()
	
	# Update description to show selection prompt
	description_label.text = option.selection_prompt
	
	# Create card container if it doesn't exist
	if not card_selection_container:
		card_selection_container = HBoxContainer.new()
		card_selection_container.alignment = BoxContainer.ALIGNMENT_CENTER
		card_selection_container.add_theme_constant_override("separation", 20)
		options_container.add_child(card_selection_container)
	
	# Clear any existing cards
	for child in card_selection_container.get_children():
		child.queue_free()
	draftable_cards.clear()
	selected_cards.clear()
	
	# Display cards based on selection type
	match option.card_selection_type:
		EventOption.CardSelectionType.CHOOSE_REWARD:
			_create_reward_selection(option)
		EventOption.CardSelectionType.REMOVE_CARDS:
			_create_removal_selection(option)
		EventOption.CardSelectionType.TRANSFORM_CARD:
			_create_transform_selection(option)

func _create_reward_selection(option: EventOption):
	"""Create card reward selection (choose from pool)"""
	var draftable_scene = preload("res://Scenes/draftable_card.tscn")
	
	# Randomly select cards from pool if pool is larger than selection count
	var cards_to_show = option.card_selection_pool.duplicate()
	if cards_to_show.size() > option.cards_to_select + 2:  # Show a few extra for choice
		cards_to_show.shuffle()
		cards_to_show = cards_to_show.slice(0, min(cards_to_show.size(), option.cards_to_select + 2))
	
	# Create draftable card for each option
	for card_data in cards_to_show:
		var draftable_card: DraftableCard = draftable_scene.instantiate()
		card_selection_container.add_child(draftable_card)
		
		draftable_card.set_data(card_data)
		draftable_card.set_mode(DraftableCard.Mode.ADD_ONLY)
		draftable_card.card_selected.connect(_on_reward_card_selected)
		
		draftable_cards.append(draftable_card)
	
	# Add skip button if optional
	if option.selection_is_optional:
		_add_skip_button()

func _create_removal_selection(option: EventOption):
	"""Create card removal selection (remove from deck)"""
	var draftable_scene = preload("res://Scenes/draftable_card.tscn")
	
	# Get unique cards in current deck with counts
	var unique_cards: Dictionary = {}
	for card in run_manager.deck:
		if not unique_cards.has(card):
			unique_cards[card] = 1
		else:
			unique_cards[card] += 1
	
	# Create draftable card for each unique card in deck
	for card_data in unique_cards.keys():
		var draftable_card: DraftableCard = draftable_scene.instantiate()
		card_selection_container.add_child(draftable_card)
		
		draftable_card.set_data(card_data)
		draftable_card.set_mode(DraftableCard.Mode.REMOVE_ONLY)
		draftable_card.set_deck_info(true, unique_cards[card_data])
		draftable_card.card_selected.connect(_on_removal_card_selected)
		
		draftable_cards.append(draftable_card)
	
	# Add skip button if optional
	if option.selection_is_optional:
		_add_skip_button()

func _create_transform_selection(option: EventOption):
	"""Create card transformation selection (upgrade/transform cards)"""
	# TODO: Implement card transformation if needed
	push_warning("Card transformation not yet implemented")
	_finish_event(current_option)

func _on_reward_card_selected(card_data: CardData, action: String):
	"""Handle when player selects a reward card"""
	if action == "add":
		# Add to selected cards
		selected_cards.append(card_data)
		
		# Add to deck immediately
		run_manager.deck.append(card_data)
		
		# Update the card to show it's been selected
		for draftable_card in draftable_cards:
			if draftable_card.data == card_data:
				draftable_card.card_count = 1
				draftable_card.update_buttons()
		
		# Check if we have enough selections
		if selected_cards.size() >= current_option.cards_to_select:
			_complete_card_selection()

func _on_removal_card_selected(card_data: CardData, action: String):
	"""Handle when player removes a card"""
	if action == "remove":
		# Add to selected (for tracking)
		selected_cards.append(card_data)
		
		# Remove from deck
		var index = run_manager.deck.find(card_data)
		if index != -1:
			run_manager.deck.remove_at(index)
		
		# Update all card displays
	
		
		# Check if we have enough removals
		if selected_cards.size() >= current_option.cards_to_select:
			_complete_card_selection()



func _add_skip_button():
	"""Add a skip button for optional card selection"""
	var skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(150, 60)
	skip_button.add_theme_font_size_override("font_size", 18)
	skip_button.pressed.connect(_complete_card_selection)
	
	options_container.add_child(skip_button)

func _complete_card_selection():
	"""Finish card selection and continue event"""
	# Clean up card selection UI
	if card_selection_container:
		card_selection_container.queue_free()
		card_selection_container = null
	
	draftable_cards.clear()
	
	# Show result or finish event
	if current_option.result_text and current_option.result_text != "":
		_show_result(current_option)
	else:
		_finish_event(current_option)

# ==== END CARD SELECTION METHODS ====


func _finish_event(option: EventOption):
	# Check if this triggers combat
	if option.triggers_combat:
		_start_combat(option)
		if option.win_con:
			run_manager.win_condition = option.win_con
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
