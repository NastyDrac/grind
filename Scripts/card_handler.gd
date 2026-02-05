extends Node
class_name CardHandler

var run_manager : RunManager
var cards : Array[Card]
var hovered_card : Card
var selected_card : Card
@onready var hand = $Hand
@onready var draw_pile = $DrawPile
@onready var discard_pile = $DiscardPile
var draw_stack : Array[Card]
var discard_stack : Array[Card]

@export_category("Hand Alignment")
@export var spacing_curve : Curve
@export var rotation_curve : Curve
@export var height_curve : Curve
@export var max_y_offset := -100.0
@export var max_angle := 15.0
@export var card_spacing := 100.0

@export_category("Hover Effect")
@export var hover_scale := 1.2
@export var hover_y_offset := -50.0
@export var hover_transition_speed := 15.0
@export var base_scale := Vector2(.75, .75)
var card_zoom := Vector2(1.5,1.5)

var cards_in_hand : Array[Card]
var card_position = {}

var is_arranging := false

# Targeting state
var is_targeting : bool = false
var frozen_card_position : Vector2
var frozen_card_scale : Vector2
var current_action : Action
var current_action_index : int = 0
var stored_targets : Array[Enemy] = []
var store_target_type : Action.TargetType
var stored_max_range : int = 0
# Targeting arrow
var targeting_arrow : Line2D

# Deck management
var deck_cards : Array[CardData] = []
var draw_amount : int = 1

func _ready():
	pass

func initialize():
	"""Called by RunManager after run_manager is set"""
	if not run_manager or not run_manager.range_manager:
		push_error("Cannot initialize CardHandler - run_manager or range_manager is null")
		return
	
	# Connect to range manager targeting signals
	run_manager.range_manager.targeting_cancelled.connect(_on_targeting_cancelled)
	run_manager.range_manager.targets_confirmed.connect(_on_targets_confirmed)
	
	# Create targeting arrow
	_create_targeting_arrow()

func _create_targeting_arrow():
	var TargetingArrow = load("res://Scripts/targeting_arrow.gd")
	targeting_arrow = Line2D.new()
	targeting_arrow.set_script(TargetingArrow)
	add_child(targeting_arrow)
	targeting_arrow.z_index = 200

func arrange_cards():
	if is_arranging or is_targeting:
		return
	
	card_position.clear()
	is_arranging = true
	cards_in_hand.assign(hand.get_children()) 
	
	var card_count = cards_in_hand.size()
	
	if card_count == 0:
		is_arranging = false
		return
	
	if card_count == 1:
		_arrange_single_card()
	else:
		_arrange_multiple_cards(card_count)
	
	is_arranging = false

func _arrange_single_card():
	var card : Card = cards_in_hand[0]
	store_card_position(card, Vector2.ZERO, 0, 0)
	if card != hovered_card:
		apply_card_transform(card, Vector2.ZERO, 0, 0, base_scale)

func _arrange_multiple_cards(card_count: int):
	for i in card_count:
		var card : Card = cards_in_hand[i]
		var hand_ratio = float(i) / float(card_count - 1)
		
		var card_pos = _calculate_card_position(hand_ratio, card_count)
		var card_rotation = _calculate_card_rotation(hand_ratio)
		
		store_card_position(card, card_pos, card_rotation, i)
		
		if card != hovered_card:
			apply_card_transform(card, card_pos, card_rotation, i, base_scale)

func _calculate_card_position(hand_ratio: float, card_count: int) -> Vector2:
	var new_card_spacing = card_spacing * (card_count - 1)
	var barrier = get_viewport().size.x / 2
	var x_offset = -new_card_spacing / 2.0
	var x_position = spacing_curve.sample(hand_ratio) * new_card_spacing + x_offset
	var y_position = height_curve.sample(hand_ratio) * max_y_offset
	
	return Vector2(x_position, y_position)

func _calculate_card_rotation(hand_ratio: float) -> float:
	return rotation_curve.sample(hand_ratio) * max_angle

func store_card_position(card: Card, pos: Vector2, rot: float, z: int):
	card_position[card] = {
		"position": pos,
		"rotation": rot,
		"z_index": z,
		"scale": base_scale
	}

func apply_card_transform(card: Card, pos: Vector2, rot: float, z: int, scale: Vector2):
	card.position = pos
	card.rotation_degrees = rot
	card.z_index = z
	card.scale = scale

func hover_card(card : Card):
	if is_targeting:
		return
	
	if card == null:
		if hovered_card:
			var card_to_reset = hovered_card
			hovered_card = null
			reset_card(card_to_reset)
		return
	
	if hovered_card and hovered_card != card:
		reset_card(hovered_card)
	
	hovered_card = card
	
	if card_position.has(card):
		card.z_index = 100

func reset_card(card: Card):
	if card_position.has(card):
		card.z_index = card_position[card]["z_index"]

func _process(delta: float) -> void:
	if not is_targeting:
		_update_card_animations(delta)
		_handle_card_selection()
		_handle_card_draw_input()
	else:
		_update_frozen_card(delta)

func _update_card_animations(delta: float):
	if hovered_card:
		_animate_hovered_card(delta)
	
	_animate_non_hovered_cards(delta)

func _animate_hovered_card(delta: float):
	if not card_position.has(hovered_card):
		return
	
	var base_pos = card_position[hovered_card]["position"]
	var target_pos = base_pos + Vector2(0, hover_y_offset)
	var target_rotation = 0.0
	var target_scale = base_scale * hover_scale
	
	var speed = hover_transition_speed * delta
	hovered_card.position = hovered_card.position.lerp(target_pos, speed)
	hovered_card.rotation_degrees = lerp(hovered_card.rotation_degrees, target_rotation, speed)
	hovered_card.scale = hovered_card.scale.lerp(target_scale, speed)

func _animate_non_hovered_cards(delta: float):
	for card in cards_in_hand:
		if card != hovered_card and card_position.has(card):
			var target_pos = card_position[card]["position"]
			var target_rotation = card_position[card]["rotation"]
			var target_scale = card_position[card]["scale"]
			
			var speed = hover_transition_speed * delta
			card.position = card.position.lerp(target_pos, speed)
			card.rotation_degrees = lerp(card.rotation_degrees, target_rotation, speed)
			card.scale = card.scale.lerp(target_scale, speed)

func _update_frozen_card(delta: float):
	if selected_card:
		selected_card.position = selected_card.position.lerp(frozen_card_position, hover_transition_speed * delta)
		selected_card.scale = selected_card.scale.lerp(frozen_card_scale, hover_transition_speed * delta)
		selected_card.rotation_degrees = lerp(selected_card.rotation_degrees, 0.0, hover_transition_speed * delta)
		
		# Update targeting arrow from card to mouse
		if targeting_arrow:
			var card_global_pos = selected_card.global_position
			var mouse_pos = get_viewport().get_mouse_position()
			targeting_arrow.show_arrow(card_global_pos, mouse_pos)

func _handle_card_selection():
	if hovered_card and Input.is_action_just_pressed("left click"):
		play_card(hovered_card)

func _handle_card_draw_input():
	if Input.is_action_just_pressed("ui_accept"):
		pass_time()

func play_card(card: Card):
	if not card or not card.data:
		return
	
	selected_card = card
	
	# Store position BEFORE removing from hand
	var stored_position = Vector2.ZERO
	var stored_scale = base_scale * hover_scale
	if card_position.has(card):
		var base_pos = card_position[card]["position"]
		stored_position = base_pos + Vector2(0, hover_y_offset)
	else:
		stored_position = card.position
		stored_scale = card.scale
	
	# Immediately remove from hand to prevent exploitation
	cards_in_hand.erase(selected_card)
	card_position.erase(selected_card)
	
	# Set frozen card position for animation
	frozen_card_position = stored_position
	frozen_card_scale = stored_scale
	
	stored_targets.clear()
	store_target_type = Action.TargetType.SINGLE_ENEMY
	stored_max_range = 0
	# Process actions
	current_action_index = 0
	_process_next_action()

func _process_next_action():
	if not selected_card or not selected_card.data:
		return
	
	# If we've processed all actions, complete the card
	if current_action_index >= selected_card.data.actions.size():
		_complete_card_play()
		return
	
	current_action = selected_card.data.actions[current_action_index]
	
	# Check if this action requires player targeting
	if current_action.requires_player_target():
		if _can_reuse_targets(current_action):
			print("reusing targets from previous action")
			_execute_action_on_targets(current_action, stored_targets)
			current_action_index += 1
			_process_next_action()
		else:
			_start_targeting_for_action(current_action)
	else:
		_execute_action_without_targeting(current_action)
		current_action_index += 1
		_process_next_action()

func _can_reuse_targets(action : Action) -> bool:
	if stored_targets.is_empty():
		return false
	if action.target_type != store_target_type:
		return false
	if action.max_range != stored_max_range:
		return false
	return true

func _start_targeting_for_action(action: Action):
	is_targeting = true
	
	# Start targeting mode in range manager
	run_manager.range_manager.start_targeting(
		action.target_type,
		action.max_range,
		action.get_num_targets(run_manager.player)
	)

func _execute_action_without_targeting(action: Action):
	match action.target_type:
		Action.TargetType.ALL_ENEMIES:
			var targets = run_manager.range_manager.get_all_enemies()
			_execute_action_on_targets(action, targets)
		Action.TargetType.SELF:
			_execute_action_on_targets(action, [run_manager.player])

func _execute_action_on_targets(action: Action, targets: Array):
	# Ensure action has player reference
	if not action.player:
		action.player = run_manager.player
	
	for target in targets:
		action.execute(target)

func _on_targets_confirmed(targets: Array[Enemy]):
	is_targeting = false
	
	# Hide targeting arrow
	if targeting_arrow:
		targeting_arrow.hide_arrow()
	
	stored_targets.assign(targets)
	store_target_type = current_action.target_type
	stored_max_range = current_action.max_range
	
	
	# Execute the current action with the selected targets
	var targets_array: Array = []
	targets_array.assign(targets)
	_execute_action_on_targets(current_action, targets_array)
	
	# Move to next action
	current_action_index += 1
	_process_next_action()

func _on_targeting_cancelled():
	is_targeting = false
	
	# Hide targeting arrow
	if targeting_arrow:
		targeting_arrow.hide_arrow()
	
	stored_targets.clear()
	# Return card to hand instead of discarding it
	if selected_card:
		# Make sure the card is parented to hand
		if selected_card.get_parent() != hand:
			selected_card.reparent(hand)
		
		# Add it back to cards_in_hand array
		if not cards_in_hand.has(selected_card):
			cards_in_hand.append(selected_card)
		
		selected_card = null
	
	current_action = null
	current_action_index = 0
	
	# Clear hover state
	hovered_card = null
	
	# Re-enable hover and rearrange cards
	arrange_cards()

func _complete_card_play():
	# Emit card played signal (spawns enemies)
	Global.card_played.emit(selected_card.data)
	
	# Card was already removed from hand in play_card(), so just move to discard
	selected_card.reparent(self)  
	discard(selected_card)
	
	# Clean up
	selected_card = null
	current_action = null
	current_action_index = 0
	
	# Clear hover state
	hovered_card = null
	
	# Rearrange remaining cards
	arrange_cards()

func discard(card : Card):
	var tween = create_tween()
	tween.tween_property(card, "position", discard_pile.global_position, .5)
	await tween.finished
	card.reparent(discard_pile)

func pass_time():
	Global.time_passed.emit()

	for i in draw_amount:
		if draw_stack.is_empty():
			reshuffle_discard_into_draw()
		
		# Check again after reshuffle - deck might be truly empty
		if not draw_stack.is_empty():
			var card = draw_stack.pop_front()
			draw_cards(card)
		else:
			print("Cannot draw - no cards available in deck or discard pile")
			break

func draw_cards(card : Card):
	if card:
		add_card_to_hand(card)
	
func reshuffle_discard_into_draw():
	for card in discard_pile.get_children():
		card.reparent(draw_pile)
		card.global_position = draw_pile.global_position
		draw_stack.append(card)

	discard_stack.clear()
	draw_stack.shuffle()
	
	if draw_stack.is_empty():
		print("Reshuffle complete - no cards available to draw")

func create_card(data : CardData):
	var new_card = load("res://Scenes/card.tscn").instantiate()
	draw_pile.add_child(new_card)
	new_card.set_data(data)
	draw_stack.append(new_card)
	new_card.card_hovered.connect(hover_card.bind())

func setup_deck(starting_deck: Array[CardData]):
	deck_cards = starting_deck.duplicate()
	deck_cards.shuffle()

func add_card_to_hand(card : Card):
	if not card:
		push_error("Cannot add null card to hand")
		return
	
	var tween = create_tween()
	tween.tween_property(card, "global_position", hand.global_position, .5)
	await tween.finished
	
	card.reparent(hand)
	cards_in_hand.append(card)
	arrange_cards()
