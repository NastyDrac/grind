extends CanvasLayer
class_name EventScene

var run_manager: RunManager
var current_event: EventData
var current_option: EventOption  


@onready var title_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/Title"
@onready var description_label: Label = $"EventMargin#Panel/EventMargin#VBoxContainer/description"
@onready var event_image: TextureRect = $"EventMargin#Panel/EventMargin#VBoxContainer/EventImage"
@onready var options_container: VBoxContainer = $"EventMargin#Panel/EventMargin#VBoxContainer/options container"


var card_selection_container: HBoxContainer = null
var draftable_cards: Array[DraftableCard] = []
var selected_cards: Array[CardData] = []


var waiting_for_draft: bool = false


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
	var button = Button.new()
	button.text = option.option_text
	button.custom_minimum_size = Vector2(400, 60)
	
	
	var can_select = option.can_select(run_manager.character.gold, run_manager.deck)
	button.disabled = not can_select
	
	
	if not can_select:
		button.tooltip_text = option.get_unavailable_reason(run_manager.character.gold, run_manager.deck)
	
	
	button.add_theme_font_size_override("font_size", 20)
	
	
	button.pressed.connect(_on_option_selected.bind(option))
	
	options_container.add_child(button)

func _on_option_selected(option: EventOption):
	
	current_option = option
	
	option_selected.emit(option)
	
	
	_process_option_results(option)
	
	
	if waiting_for_draft:
		return
	
	
	if option.card_selection_type != EventOption.CardSelectionType.NONE:
		_show_card_selection(option)
	elif option.result_text and option.result_text != "":
		_show_result(option)
	else:
		_finish_event(option)

func _show_result(option: EventOption):
	
	for child in options_container.get_children():
		child.queue_free()
	
	
	description_label.text = option.result_text
	
	
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
	
	
	if option.gold_cost > 0:
		run_manager.character.gold -= option.gold_cost
	if option.gold_reward > 0:
		run_manager.character.gold += option.gold_reward
	run_manager.ui_bar.set_gold()
	
	
	if option.health_change != 0:
		run_manager.character.current_health += option.health_change
		
		run_manager.character.current_health = clamp(
			run_manager.character.current_health,
			0,
			run_manager.character.max_health.calculate(run_manager.player)
		)
		run_manager.ui_bar.set_health()
	
	
	if option.random_selection:
		
		waiting_for_draft = true
		
		
		visible = false
		
		
		run_manager.create_draft_screen()
		
		
		if run_manager.current_draft_screen:
			run_manager.current_draft_screen.draft_completed.connect(_on_draft_completed)
	else:
		
		for card in option.cards_to_add:
			run_manager.deck.append(card)
	
	
	for card in option.cards_to_remove:
		run_manager.deck.erase(card)

func _on_draft_completed():
	"""Called when the draft screen finishes"""
	waiting_for_draft = false
	
	
	visible = true
	
	
	if run_manager.current_draft_screen:
		if run_manager.current_draft_screen.draft_completed.is_connected(_on_draft_completed):
			run_manager.current_draft_screen.draft_completed.disconnect(_on_draft_completed)
	
	
	if current_option.result_text and current_option.result_text != "":
		_show_result(current_option)
	else:
		_finish_event(current_option)

# ==== CARD SELECTION METHODS ====

func _show_card_selection(option: EventOption):
	"""Display card selection interface based on option type"""
	
	for child in options_container.get_children():
		child.queue_free()
	
	
	description_label.text = option.selection_prompt
	
	
	if not card_selection_container:
		card_selection_container = HBoxContainer.new()
		card_selection_container.alignment = BoxContainer.ALIGNMENT_CENTER
		card_selection_container.add_theme_constant_override("separation", 20)
		options_container.add_child(card_selection_container)
	
	
	for child in card_selection_container.get_children():
		child.queue_free()
	draftable_cards.clear()
	selected_cards.clear()
	
	
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
	
	
	var cards_to_show = option.card_selection_pool.duplicate()
	if cards_to_show.size() > option.cards_to_select + 2:  # Show a few extra for choice
		cards_to_show.shuffle()
		cards_to_show = cards_to_show.slice(0, min(cards_to_show.size(), option.cards_to_select + 2))
	
	
	for card_data in cards_to_show:
		var draftable_card: DraftableCard = draftable_scene.instantiate()
		card_selection_container.add_child(draftable_card)
		
		draftable_card.set_data(card_data)
		draftable_card.set_mode(DraftableCard.Mode.ADD_ONLY)
		draftable_card.card_selected.connect(_on_reward_card_selected)
		
		draftable_cards.append(draftable_card)
	
	
	if option.selection_is_optional:
		_add_skip_button()

func _create_removal_selection(option: EventOption):
	"""Create card removal selection (remove from deck)"""
	var draftable_scene = preload("res://Scenes/draftable_card.tscn")
	
	
	var unique_cards: Dictionary = {}
	for card in run_manager.deck:
		if not unique_cards.has(card):
			unique_cards[card] = 1
		else:
			unique_cards[card] += 1
	
	
	for card_data in unique_cards.keys():
		var draftable_card: DraftableCard = draftable_scene.instantiate()
		card_selection_container.add_child(draftable_card)
		
		draftable_card.set_data(card_data)
		draftable_card.set_mode(DraftableCard.Mode.REMOVE_ONLY)
		draftable_card.set_deck_info(true, unique_cards[card_data])
		draftable_card.card_selected.connect(_on_removal_card_selected)
		
		draftable_cards.append(draftable_card)
	
	
	if option.selection_is_optional:
		_add_skip_button()

func _create_transform_selection(option: EventOption):
	"""Create card transformation selection (upgrade/transform cards)"""
	
	push_warning("Card transformation not yet implemented")
	_finish_event(current_option)

func _on_reward_card_selected(card_data: CardData, action: String):
	"""Handle when player selects a reward card"""
	if action == "add":
		
		selected_cards.append(card_data)
		
		
		run_manager.deck.append(card_data)
		
		
		for draftable_card in draftable_cards:
			if draftable_card.data == card_data:
				draftable_card.card_count = 1
				draftable_card.update_buttons()
		
		
		if selected_cards.size() >= current_option.cards_to_select:
			_complete_card_selection()

func _on_removal_card_selected(card_data: CardData, action: String):
	"""Handle when player removes a card"""
	if action == "remove":
		
		selected_cards.append(card_data)
		
		
		var index = run_manager.deck.find(card_data)
		if index != -1:
			run_manager.deck.remove_at(index)
		
		
	
		
		
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
	
	if card_selection_container:
		card_selection_container.queue_free()
		card_selection_container = null
	
	draftable_cards.clear()
	
	
	if current_option.result_text and current_option.result_text != "":
		_show_result(current_option)
	else:
		_finish_event(current_option)

# ==== END CARD SELECTION METHODS ====


func _finish_event(option: EventOption):
	
	if option.triggers_combat:
		_start_combat(option)
		if option.win_con:
			run_manager.win_condition = option.win_con
	else:
		
		event_completed.emit()
		queue_free()

func _start_combat(option: EventOption):
	
	if option.combat_horde.size() > 0:
		run_manager.horde = option.combat_horde.duplicate()
	
	
	run_manager.initial_enemy_count = int(run_manager.initial_enemy_count * option.combat_difficulty_modifier)
	
	# Emit event completed and let run_manager handle starting combat
	event_completed.emit()
	queue_free()
	
	# The run_manager should call begin_wave() after this
