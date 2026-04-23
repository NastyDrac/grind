extends Action
class_name DrawAction


@export var card_count_calculator: ValueCalculator

func get_action_type() -> String:
	return "Draw"

func execute(target) -> void:
	
	if not player:
		push_error("DrawCardAction requires valid Character")
		return
	
	
	var card_handler = _get_card_handler()
	if not card_handler:
		push_error("DrawCardAction: Could not find card_handler")
		return
	
	
	var cards_to_draw = _calculate_card_count()
	
	
	
	# Draw cards immediately without waiting for animation
	for i in cards_to_draw:
		if card_handler.draw_stack.is_empty():
			card_handler.reshuffle_discard_into_draw()
		
		if not card_handler.draw_stack.is_empty():
			var card = card_handler.draw_stack.pop_front()
			# Add directly to hand without animation during action execution
			card.reparent(card_handler.hand)
			card_handler.cards_in_hand.append(card)
			
	
	# Arrange cards after all draws complete
	card_handler.arrange_cards()

func get_description_with_values(character: Character) -> String:
	if not character or not card_count_calculator:
		return "Draw cards"
	
	var count = card_count_calculator.calculate(character)
	var formula = card_count_calculator.formula
	
	# Only show formula if it's not just a simple number
	var show_formula = not formula.is_valid_int()
	
	var desc = ""
	if count == 1:
		if show_formula:
			desc = "Draw %d card (%s)" % [count, _format_formula_display(formula)]
		else:
			desc = "Draw %d card" % count
	else:
		if show_formula:
			desc = "Draw %d cards (%s)" % [count, _format_formula_display(formula)]
		else:
			desc = "Draw %d cards" % count
	
	# Add range inline if max_range > 0
	if max_range > 0:
		desc += " - Range: %d" % max_range
	
	return desc

func _calculate_card_count() -> int:
	if card_count_calculator and player:
		return card_count_calculator.calculate(player)
	return 1

func _get_card_handler() -> CardHandler:
	if card_handler:
		return card_handler
	if player and player.run_manager and player.run_manager.card_handler:
		return player.run_manager.card_handler
	return null

func requires_player_target() -> bool:
	return false
