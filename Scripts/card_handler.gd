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
@export var card_height_px : int
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

# Action execution queue - stores all actions with their targets before executing
var action_queue : Array[Dictionary] = []  # Array of {action: Action, targets: Array}

# Card targeting state
var is_card_targeting : bool = false
var selected_cards : Array[Card] = []
var card_target_type : Action.TargetType
var card_target_max : int = 1  # Maximum number of cards to select

# Card staging area (for visual separation like Slay the Spire)
var staged_card_positions : Dictionary = {}  # Card -> original position for return
var staging_y_offset : float = -400.0  # How far above hand to lift cards (well above hand for clear separation)
var staging_spacing : float = 200.0  # Space between staged cards (increased for better visibility)

# Card targeting UI
var card_targeting_ui : CanvasLayer
var card_targeting_label : Label
var card_targeting_confirm_btn : Button

# Helper functions for card targeting UI
func _show_card_targeting_ui(instruction: String):
	"""Show the card targeting UI with instruction text"""
	if not card_targeting_ui:
		return
	
	if card_targeting_label:
		card_targeting_label.text = instruction
	if card_targeting_confirm_btn:
		card_targeting_confirm_btn.disabled = true
	
	card_targeting_ui.show()

func _hide_card_targeting_ui():
	"""Hide the card targeting UI"""
	if card_targeting_ui:
		card_targeting_ui.hide()

func _update_card_targeting_ui():
	"""Update the UI based on current selection"""
	if not card_targeting_label or not card_targeting_confirm_btn:
		return
	
	# Count how many cards are ACTUALLY available to select (excluding the played card)
	var available_count = 0
	for card in cards_in_hand:
		if card != selected_card:  # Don't count the card being played
			available_count += 1
	
	# Adjust target max if there aren't enough cards
	var effective_max = min(card_target_max, available_count)
	
	# If there are literally no cards to select, allow confirming with 0 cards
	if available_count == 0:
		card_targeting_label.text = "No cards available - click to continue"
		card_targeting_confirm_btn.disabled = false  # Allow confirming with 0 cards
		card_targeting_confirm_btn.text = "Continue"
		return
	
	# Reset confirm button text
	card_targeting_confirm_btn.text = "Confirm"
	
	if selected_cards.is_empty():
		if effective_max < card_target_max:
			card_targeting_label.text = "Select %d card(s) (only %d available)" % [card_target_max, effective_max]
		else:
			card_targeting_label.text = "Select %d card(s)" % card_target_max
		card_targeting_confirm_btn.disabled = true
	else:
		var card_names = []
		for card in selected_cards:
			card_names.append(card.data.card_name)
		
		# Allow confirm if we've selected the max available (even if less than target)
		if selected_cards.size() < effective_max:
			card_targeting_label.text = "Selected %d/%d: %s (Select more)" % [selected_cards.size(), effective_max, ", ".join(card_names)]
			card_targeting_confirm_btn.disabled = true
		else:
			if effective_max < card_target_max:
				card_targeting_label.text = "Selected %d/%d: %s (Click to confirm - not enough cards)" % [selected_cards.size(), card_target_max, ", ".join(card_names)]
			else:
				card_targeting_label.text = "Selected %d/%d: %s (Click to confirm)" % [selected_cards.size(), card_target_max, ", ".join(card_names)]
			card_targeting_confirm_btn.disabled = false

# Targeting arrow
var targeting_arrow : Line2D

# Deck management
var deck_cards : Array[CardData] = []

@export_category("Draw Mode")
@export var discard_and_draw_mode : bool = false
@export var cards_to_draw : int = 5 

func _input(event: InputEvent) -> void:
	# Card targeting has no cancel option - you're committed once actions have executed
	pass

func initialize():
	# Connect to range manager targeting signals
	run_manager.range_manager.targeting_cancelled.connect(_on_targeting_cancelled)
	run_manager.range_manager.targets_confirmed.connect(_on_targets_confirmed)
	
	_create_targeting_arrow()
	_create_card_targeting_ui()

func _create_card_targeting_ui():
	"""Create the card targeting UI overlay inline"""
	card_targeting_ui = CanvasLayer.new()
	add_child(card_targeting_ui)
	
	# Main panel at top of screen
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 20
	panel.offset_bottom = 100
	card_targeting_ui.add_child(panel)
	
	# Container for label and buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	
	# Instruction label - STORE REFERENCE
	card_targeting_label = Label.new()
	card_targeting_label.text = "Select a card"
	card_targeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_targeting_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(card_targeting_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(spacer)
	
	# Confirm button - STORE REFERENCE
	card_targeting_confirm_btn = Button.new()
	card_targeting_confirm_btn.text = "Confirm"
	card_targeting_confirm_btn.disabled = true
	card_targeting_confirm_btn.pressed.connect(_on_confirm_card_selection)
	hbox.add_child(card_targeting_confirm_btn)
	
	# Note: No cancel button - once you reach card selection, you're committed
	
	# Hide by default
	card_targeting_ui.hide()

func _create_targeting_arrow():
	var TargetingArrow = load("res://Scripts/targeting_arrow.gd")
	targeting_arrow = Line2D.new()
	targeting_arrow.set_script(TargetingArrow)
	add_child(targeting_arrow)
	targeting_arrow.z_index = 200

func arrange_cards():
	# Block during any kind of targeting to prevent cards_in_hand from being refreshed
	if is_arranging or is_targeting or is_card_targeting:
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
	# Only block hovering during enemy targeting, not card targeting
	if is_targeting:
		return
	
	# During card targeting, don't allow hovering the played card
	if is_card_targeting and card == selected_card:
		return
	
	# Don't allow hovering cards that are already staged
	if is_card_targeting and card in selected_cards:
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
	# Handle enemy targeting (frozen card with arrow)
	if is_targeting:
		_update_frozen_card(delta)
	else:
		# Animate cards when not enemy targeting
		_update_card_animations(delta)
		_handle_card_draw_input()
	
	# Always handle card selection (for both playing cards AND selecting cards to discard)
	_handle_card_selection()

func _update_card_animations(delta: float):
	if hovered_card:
		_animate_hovered_card(delta)
	
	_animate_non_hovered_cards(delta)

func _animate_hovered_card(delta: float):
	if not card_position.has(hovered_card):
		return
	
	var target_scale      := base_scale * hover_scale
	var viewport_height   = get_viewport().size.y
	var scaled_height     = card_height_px * target_scale.y
	# Global Y where the card's top must sit so its bottom edge = screen bottom
	var target_global_y   = viewport_height - scaled_height
	# Convert to Hand-local space
	var target_local_y    = hand.to_local(Vector2(0.0, target_global_y)).y

	var base_pos   = card_position[hovered_card]["position"]
	var target_pos = Vector2(base_pos.x, target_local_y)

	var speed = hover_transition_speed * delta
	hovered_card.position         = hovered_card.position.lerp(target_pos, speed)
	hovered_card.rotation_degrees = lerp(hovered_card.rotation_degrees, 0.0, speed)
	hovered_card.scale            = hovered_card.scale.lerp(target_scale, speed)
func _animate_non_hovered_cards(delta: float):
	for card in cards_in_hand:
		# Skip cards that are staged (being selected for discard)
		if card in selected_cards:
			continue
		
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
		
		if targeting_arrow:
			var card_global_pos = selected_card.global_position
			var mouse_pos = get_viewport().get_mouse_position()
			targeting_arrow.show_arrow(card_global_pos, mouse_pos)

func _handle_card_selection():
	# Don't allow card selection during enemy targeting OR card targeting
	if is_targeting or is_card_targeting:
		# During card targeting, handle card clicks
		if is_card_targeting and Input.is_action_just_pressed("left click"):
			if hovered_card:
				_on_card_selected_for_targeting(hovered_card)
		return
	
	# Normal card play when not targeting anything
	if Input.is_action_just_pressed("left click"):
		if hovered_card:
			play_card(hovered_card)

func _handle_card_draw_input():
	if Input.is_action_just_pressed("ui_accept"):
		pass_time()

func play_card(card: Card):
	# Safety check: Don't allow playing a card while already targeting
	if is_targeting or is_card_targeting:
		return
	
	if not card or not card.data:
		return
	
	selected_card = card
	
	var stored_position = Vector2.ZERO
	var stored_scale = base_scale * hover_scale
	if card_position.has(card):
		var base_pos = card_position[card]["position"]
		stored_position = base_pos + Vector2(0, hover_y_offset)
	else:
		stored_position = card.position
		stored_scale = card.scale
	
	cards_in_hand.erase(selected_card)
	card_position.erase(selected_card)
	

	frozen_card_position = stored_position
	frozen_card_scale = stored_scale
	
	stored_targets.clear()
	store_target_type = Action.TargetType.SINGLE_ENEMY
	stored_max_range = 0
	current_action_index = 0
	action_queue.clear()  # Clear the action queue
	
	# Start collecting targets for all actions
	_collect_targets_for_next_action()

func _collect_targets_for_next_action():
	"""Collect targets for actions without executing them yet"""
	if not selected_card or not selected_card.data:
		return
	
	# If we've collected targets for all actions, execute them all now
	if current_action_index >= selected_card.data.actions.size():
		await _execute_queued_non_card_actions()
		return
	
	current_action = selected_card.data.actions[current_action_index]
	
	# Set card_handler reference for card-targeting actions
	current_action.card_handler = self
	
	# Check what type of action this is and collect targets
	if current_action.requires_player_target():
		# Enemy targeting
		if _can_reuse_targets(current_action):
			# Reuse previous targets
			action_queue.append({"action": current_action, "targets": stored_targets.duplicate()})
			current_action_index += 1
			await _collect_targets_for_next_action()
		else:
			# Need new targeting
			_start_targeting_for_action(current_action)
	elif current_action.requires_card_target():
		# IMPORTANT: Before card targeting, execute all queued actions so far
		# This ensures draws happen before selecting cards to discard
		if not action_queue.is_empty():
			await _execute_queued_non_card_actions()
		else:
			# No actions to execute yet, just start card targeting
			_start_card_targeting_for_action(current_action)
	elif current_action.is_automatic_card_action():
		# Automatic card actions (random, all, etc.)
		var targets = _get_automatic_card_targets(current_action)
		action_queue.append({"action": current_action, "targets": targets})
		current_action_index += 1
		await _collect_targets_for_next_action()
	else:
		# No targeting needed - get targets automatically (like DrawAction)
		var targets = _get_automatic_targets(current_action)
		action_queue.append({"action": current_action, "targets": targets})
		current_action_index += 1
		await _collect_targets_for_next_action()

func _execute_queued_non_card_actions():
	"""Execute all non-card actions in the queue, then continue collecting targets"""
	for action_data in action_queue:
		var action = action_data["action"]
		var targets = action_data["targets"]
		
		if not action.player:
			action.player = run_manager.player
		
		# Fire animation+damage without awaiting — damage still lands after the
		# animation internally, but the card handler moves on immediately so
		# the card is discarded and enemies spawn without delay.
		if targets.is_empty():
			action.play_animation_and_execute(run_manager.player)
		else:
			for i in range(targets.size()):
				var target = targets[i]
				action.play_animation_and_execute(target)
	
	# Clear executed actions from queue
	action_queue.clear()
	
	# Rearrange hand (cards may have been drawn)
	arrange_cards()
	
	# Continue with next action (will be card targeting)
	if current_action_index < selected_card.data.actions.size():
		await _collect_targets_for_next_action()
	else:
		# All done
		_complete_card_play()

func _get_automatic_targets(action: Action) -> Array:
	"""Get targets for actions that don't require player input"""
	match action.target_type:
		Action.TargetType.ALL_ENEMIES:
			return run_manager.range_manager.get_all_enemies()
		Action.TargetType.SELF:
			return [run_manager.player]
	return []

func _get_automatic_card_targets(action: Action) -> Array:
	"""Get card targets for automatic card actions"""
	var targets = []
	
	match action.target_type:
		Action.TargetType.RANDOM_CARD_IN_HAND:
			if action.has_method("get_random_cards_from_hand"):
				targets = action.get_random_cards_from_hand()
			else:
				if not cards_in_hand.is_empty():
					targets = [cards_in_hand.pick_random()]
		Action.TargetType.ALL_CARDS_IN_HAND:
			targets = cards_in_hand.duplicate()
	
	return targets

func _execute_all_queued_actions():
	"""Execute all actions with their collected targets"""
	for action_data in action_queue:
		var action = action_data["action"]
		var targets = action_data["targets"]
		
		if not action.player:
			action.player = run_manager.player
		
		# Execute based on action type
		if action.requires_card_target() or action.is_automatic_card_action():
			# Card actions - pass array of cards (can be empty for draw/block/etc)
			action.execute(targets)
		elif targets.is_empty():
			# Actions with no targets (like DrawAction with SELF)
			# Execute with player as target
			action.execute(run_manager.player)
		else:
			# Enemy targeting actions
			for target in targets:
				action.execute(target)
	
	# Clear the queue
	action_queue.clear()
	
	# Rearrange hand after all actions (cards may have been drawn/discarded)
	arrange_cards()
	
	# Complete the card play
	_complete_card_play()

func _can_reuse_targets(action : Action) -> bool:
	if stored_targets.is_empty():
		return false
	if action.target_type != store_target_type:
		return false
	if action.max_range != stored_max_range:
		return false
	return true

# ============================================================================
# ENEMY TARGETING
# ============================================================================

func _start_targeting_for_action(action: Action):
	is_targeting = true
	
	var num_targets = action.get_num_targets(run_manager.player)
	
	run_manager.range_manager.start_targeting(
		action.target_type,
		action.max_range,
		num_targets
	)

func _on_targets_confirmed(targets: Array[Enemy]):
	
	is_targeting = false
	
	if targeting_arrow:
		targeting_arrow.hide_arrow()
	
	stored_targets.assign(targets)
	store_target_type = current_action.target_type
	stored_max_range = current_action.max_range
	
	# Queue this action with its targets instead of executing
	var targets_array: Array = []
	targets_array.assign(targets)
	action_queue.append({"action": current_action, "targets": targets_array})
	
	
	current_action_index += 1
	await _collect_targets_for_next_action()

func _on_targeting_cancelled():
	is_targeting = false
	
	if targeting_arrow:
		targeting_arrow.hide_arrow()
	
	# Clear the action queue - nothing should execute
	action_queue.clear()
	
	# Reset action index
	current_action_index = 0
	current_action = null
	stored_targets.clear()
	
	if selected_card:
	
		if selected_card.get_parent() != hand:
			selected_card.reparent(hand)
		
		
		if not cards_in_hand.has(selected_card):
			cards_in_hand.append(selected_card)
		
		selected_card = null
	
	hovered_card = null
	arrange_cards()

# ============================================================================
# CARD TARGETING
# ============================================================================

func _start_card_targeting_for_action(action: Action):
	"""Start interactive card targeting - player clicks a card"""
	is_card_targeting = true
	card_target_type = action.target_type
	selected_cards.clear()
	staged_card_positions.clear()  # Clear any previous staging
	
	# Get how many cards to select
	
	if action.card_count_calculator is ValueCalculator:
		card_target_max = action.card_count_calculator.calculate(run_manager.player)
	else:
		# Fallback for backwards compatibility if someone uses an int
		card_target_max = action.card_count_calculator.calculate()
	
	
	
	# Determine instruction text based on action type
	var instruction = "Select a card"
	if action is DiscardAction:
		if card_target_max > 1:
			instruction = "Select %d cards to discard" % card_target_max
		else:
			instruction = "Select a card to discard"
	elif action is ExhaustAction:
		if card_target_max > 1:
			instruction = "Select %d cards to exhaust" % card_target_max
		else:
			instruction = "Select a card to exhaust"
	
	# Show the UI
	_show_card_targeting_ui(instruction)
	
	# Make cards selectable based on target type
	match action.target_type:
		Action.TargetType.CARD_IN_HAND:
			_make_hand_cards_selectable()
		Action.TargetType.CARD_IN_DISCARD:
			_make_discard_cards_selectable()
		Action.TargetType.CARD_IN_DRAW:
			_make_draw_cards_selectable()
	
	# CRITICAL: Update UI immediately to handle zero available cards case
	_update_card_targeting_ui()

func _make_hand_cards_selectable():
	"""Make cards in hand clickable for targeting"""
	# Cards are already clickable via hover system
	# You could add visual feedback here (glow, highlight, etc.)
	for card in cards_in_hand:
		# Skip the card being played
		if card == selected_card:
			continue
		# If your Card class has a set_selectable method, call it here
		if card.has_method("set_selectable"):
			card.set_selectable(true)

func _make_discard_cards_selectable():
	# TODO: Implement discard pile selection UI
	pass

func _make_draw_cards_selectable():
	pass
	# TODO: Implement draw pile selection UI

func _make_all_cards_unselectable():
	"""Reset all cards to non-selectable state"""
	for card in cards_in_hand:
		if card.has_method("set_selectable"):
			card.set_selectable(false)

func _on_card_selected_for_targeting(card: Card):
	"""Called when player clicks a card during card targeting - toggles selection"""
	if not is_card_targeting:
		return
	
	# CRITICAL: Don't allow selecting the card being played
	if card == selected_card:
		return
	
	# Validate the card is a valid target
	var is_valid = false
	match card_target_type:
		Action.TargetType.CARD_IN_HAND:
			# Must be in the cards_in_hand array (not just a child of hand node)
			is_valid = card in cards_in_hand
		Action.TargetType.CARD_IN_DISCARD:
			is_valid = card.get_parent() == discard_pile
		Action.TargetType.CARD_IN_DRAW:
			is_valid = card in draw_stack
	
	if not is_valid:
		return
	
	# Toggle selection - allow multiple cards up to card_target_max
	if card in selected_cards:
		# Deselect - return to hand
		selected_cards.erase(card)
		if card.has_method("set_selected"):
			card.set_selected(false)
		_return_card_to_hand(card)
	else:
		# Select if we haven't reached the limit
		if selected_cards.size() < card_target_max:
			selected_cards.append(card)
			if card.has_method("set_selected"):
				card.set_selected(true)
			_move_card_to_staging(card)

	
	# Update UI
	_update_card_targeting_ui()
	
	# Rearrange remaining cards in hand
	_arrange_unstaged_cards()

func _on_confirm_card_selection():
	"""Called when player clicks the Confirm button"""
	if selected_cards.is_empty():
		return
	
	# Execute the current card action immediately
	var cards_to_action = selected_cards.duplicate()
	if not current_action.player:
		current_action.player = run_manager.player
	current_action.execute(cards_to_action)
	
	# Clear all card selection visuals and staging
	_clear_staging_area()
	
	# Reset targeting state
	is_card_targeting = false
	selected_cards.clear()
	_make_all_cards_unselectable()
	_hide_card_targeting_ui()
	
	# Rearrange hand after discard
	arrange_cards()
	
	# Continue with any remaining actions
	current_action_index += 1
	if current_action_index < selected_card.data.actions.size():
		await _collect_targets_for_next_action()
	else:
		# All done
		_complete_card_play()

func _on_card_selection_cancelled():
	"""Called when player cancels card selection"""
	_cancel_card_targeting()

# ============================================================================
# CARD STAGING AREA (Slay the Spire style)
# ============================================================================

func _move_card_to_staging(card: Card):
	"""Move a card up to the staging area above the hand"""
	# Store original position if not already stored
	if not staged_card_positions.has(card):
		if card_position.has(card):
			staged_card_positions[card] = card_position[card].duplicate()
		else:
			staged_card_positions[card] = {
				"position": card.position,
				"rotation": card.rotation_degrees,
				"z_index": card.z_index,
				"scale": card.scale
			}
	
	# Recenter ALL staged cards whenever selection changes
	_recenter_staged_cards()

func _recenter_staged_cards():
	"""Recenter all staged cards based on current selection"""
	var total_staged = selected_cards.size()
	if total_staged == 0:
		return
	
	# Calculate positions for all staged cards
	var total_width = (total_staged - 1) * staging_spacing
	var start_x = -total_width / 2.0
	
	for i in range(total_staged):
		var card = selected_cards[i]
		var staging_x = start_x + (i * staging_spacing)
		var target_pos = Vector2(staging_x, staging_y_offset)
		var target_rot = 0.0  # No rotation when staged
		var target_scale = base_scale * 1.1  # Slightly larger
		
		# Animate to staging position
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", target_pos, 0.2)
		tween.tween_property(card, "rotation_degrees", target_rot, 0.2)
		tween.tween_property(card, "scale", target_scale, 0.2)
		
		# Bring to front
		card.z_index = 200

func _return_card_to_hand(card: Card):
	"""Return a staged card back to its position in hand"""
	if not staged_card_positions.has(card):
		return
	
	var original = staged_card_positions[card]
	
	# Animate back to original position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position", original["position"], 0.2)
	tween.tween_property(card, "rotation_degrees", original["rotation"], 0.2)
	tween.tween_property(card, "scale", original["scale"], 0.2)
	tween.tween_property(card, "z_index", original["z_index"], 0.2)
	
	# Remove from staging tracking
	staged_card_positions.erase(card)
	
	# Recenter remaining staged cards
	_recenter_staged_cards()

func _arrange_unstaged_cards():
	"""Rearrange only the cards still in hand (not staged)"""
	var unstaged_cards = []
	for card in cards_in_hand:
		if card not in selected_cards:
			unstaged_cards.append(card)
	
	if unstaged_cards.is_empty():
		return
	
	var card_count = unstaged_cards.size()
	
	if card_count == 1:
		var card = unstaged_cards[0]
		store_card_position(card, Vector2.ZERO, 0, 0)
		apply_card_transform(card, Vector2.ZERO, 0, 0, base_scale)
	else:
		for i in card_count:
			var card = unstaged_cards[i]
			var hand_ratio = float(i) / float(card_count - 1)
			
			var card_pos = _calculate_card_position(hand_ratio, card_count)
			var card_rotation = _calculate_card_rotation(hand_ratio)
			
			store_card_position(card, card_pos, card_rotation, i)
			apply_card_transform(card, card_pos, card_rotation, i, base_scale)

func _clear_staging_area():
	"""Clear all staged cards and positions"""
	for card in selected_cards:
		if card.has_method("set_selected"):
			card.set_selected(false)
	
	staged_card_positions.clear()

# ============================================================================
# END CARD STAGING AREA
# ============================================================================

func _cancel_card_targeting():
	"""Cancel card targeting and return card to hand"""
	
	# Clear the action queue - nothing should execute
	action_queue.clear()
	
	# Clear selection visuals
	for card in selected_cards:
		if card.has_method("set_selected"):
			card.set_selected(false)
	
	is_card_targeting = false
	selected_cards.clear()
	_make_all_cards_unselectable()
	
	# Hide the UI
	_hide_card_targeting_ui()
	
	if selected_card:
		if selected_card.get_parent() != hand:
			selected_card.reparent(hand)
		
		if not cards_in_hand.has(selected_card):
			cards_in_hand.append(selected_card)
		
		selected_card = null
	
	current_action = null
	current_action_index = 0
	
	hovered_card = null
	arrange_cards()

# ============================================================================
# AUTOMATIC CARD ACTIONS
# ============================================================================

func _execute_automatic_card_action(action: Action):
	"""Execute actions that don't need player targeting"""
	var targets = []
	
	match action.target_type:
		Action.TargetType.RANDOM_CARD_IN_HAND:
			# Get random cards from hand
			if action.has_method("get_random_cards_from_hand"):
				targets = action.get_random_cards_from_hand()
			else:
				# Fallback: get one random card
				if not cards_in_hand.is_empty():
					targets = [cards_in_hand.pick_random()]
		
		Action.TargetType.ALL_CARDS_IN_HAND:
			# Target all cards currently in hand
			targets = cards_in_hand.duplicate()
	
	if not targets.is_empty():
		_execute_action_on_cards(action, targets)

func _execute_action_on_cards(action: Action, cards: Array):
	"""Execute an action on card targets"""
	if not action.card_handler:
		action.card_handler = self
	
	for card in cards:
		await action.play_animation_and_execute(card)

# ============================================================================
# STANDARD ACTION EXECUTION
# ============================================================================

func _execute_action_without_targeting(action: Action):
	match action.target_type:
		Action.TargetType.ALL_ENEMIES:
			var targets = run_manager.range_manager.get_all_enemies()
			_execute_action_on_targets(action, targets)
		Action.TargetType.SELF:
			_execute_action_on_targets(action, [run_manager.player])

func _execute_action_on_targets(action: Action, targets: Array):
	if not action.player:
		action.player = run_manager.player
	
	for target in targets:
		action.execute(target)

func _complete_card_play():
	Global.card_played.emit(selected_card.data)

	selected_card.reparent(self)

	if selected_card.data and selected_card.data.exhaust:
		selected_card.queue_free()
	else:
		discard(selected_card)
	

	selected_card = null
	current_action = null
	current_action_index = 0
	

	hovered_card = null
	

	arrange_cards()

# ============================================================================
# DECK MANAGEMENT
# ============================================================================

func discard(card : Card):
	var tween = create_tween()
	tween.tween_property(card, "position", discard_pile.global_position, .5)
	await tween.finished
	card.reparent(discard_pile)

func pass_time():
	Global.time_passed.emit()
	
	if discard_and_draw_mode:
		
		await discard_hand()
		
		await draw_multiple_cards(cards_to_draw)
	else:
	
		if draw_stack.is_empty():
			reshuffle_discard_into_draw()
			
		
		if not draw_stack.is_empty():
			var card = draw_stack.pop_front()
			draw_cards(card)

func draw_cards(card : Card):
	if card:
		add_card_to_hand(card)

func discard_hand():
	"""Discards all cards currently in hand"""
	var cards_to_discard = cards_in_hand.duplicate()
	cards_in_hand.clear()
	card_position.clear()

	var discard_tweens = []
	var exhaust_cards = []
	for card in cards_to_discard:
		card.reparent(self)
		if card.data and card.data.exhaust:
			exhaust_cards.append(card)
		else:
			var tween = create_tween()
			tween.tween_property(card, "position", discard_pile.global_position, .5)
			discard_tweens.append(tween)

	for tween in discard_tweens:
		await tween.finished

	for card in cards_to_discard:
		if card.data and card.data.exhaust:
			card.queue_free()
		else:
			card.reparent(discard_pile)

func draw_multiple_cards(amount: int):
	"""Draws multiple cards from the draw pile, one at a time with animation"""
	for i in amount:
		if draw_stack.is_empty():
			reshuffle_discard_into_draw()
		
	
		if not draw_stack.is_empty():
			var card = draw_stack.pop_front()
			draw_cards(card)
			
			await get_tree().create_timer(0.2).timeout
		else:
			break
	
func reshuffle_discard_into_draw():
	for card in discard_pile.get_children():
		card.reparent(draw_pile)
		card.global_position = draw_pile.global_position
		draw_stack.append(card)

	discard_stack.clear()
	draw_stack.shuffle()
	

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
		return
	
	var tween = create_tween()
	tween.tween_property(card, "global_position", hand.global_position, .5)
	await tween.finished
	
	card.reparent(hand)
	cards_in_hand.append(card)
	arrange_cards()
