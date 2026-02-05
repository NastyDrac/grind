extends Action
class_name DrawAction

# Number of cards to draw
@export var card_count_calculator: ValueCalculator

func get_action_type() -> String:
	return "Draw"

func execute(target) -> void:
	# Target is ignored for draw actions - it targets SELF (the player)
	if not player:
		push_error("DrawCardAction requires valid Character")
		return
	
	# Get the card handler from run_manager
	var card_handler = _get_card_handler()
	if not card_handler:
		push_error("DrawCardAction: Could not find card_handler")
		return
	
	# Calculate how many cards to draw
	var cards_to_draw = _calculate_card_count()
	
	print("Drawing %d cards" % cards_to_draw)
	
	# Draw cards without passing time
	for i in cards_to_draw:
		if card_handler.draw_stack.is_empty():
			card_handler.reshuffle_discard_into_draw()
		
		if not card_handler.draw_stack.is_empty():
			var card = card_handler.draw_stack.pop_front()
			card_handler.draw_cards(card)

func get_description_with_values(character: Character) -> String:
	if not character or not card_count_calculator:
		return "Draw cards"
	
	# Calculate card count
	var count = card_count_calculator.calculate(character)
	
	# Format the formula with stat names
	var formula_display = _format_formula_display(card_count_calculator.formula)
	
	# Build description
	if count == 1:
		return "Draw: §%d§ card (%s)" % [count, formula_display]
	else:
		return "Draw: §%d§ cards (%s)" % [count, formula_display]

func _calculate_card_count() -> int:
	if card_count_calculator and player:
		return card_count_calculator.calculate(player)
	return 1

func _get_card_handler() -> CardHandler:
	# Get card handler from player's run_manager
	if player and player.run_manager and player.run_manager.card_handler:
		return player.run_manager.card_handler
	return null

# Override: Draw actions don't need targeting
func requires_player_target() -> bool:
	return false
