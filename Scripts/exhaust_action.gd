extends Action
class_name ExhaustAction

# Exhaust mechanic: Permanently remove card(s) from combat
# Exhausted cards don't go to discard pile and won't be shuffled back

# Number of cards to exhaust (uses ValueCalculator for dynamic values)
@export var num_cards: ValueCalculator

func get_action_type() -> String:
	return "Exhaust"

func execute(target) -> void:
	# Target can be a Card or an Array[Card]
	if target is Array:
		for card in target:
			_exhaust_card(card)
	elif target is Card:
		_exhaust_card(target)
	else:
		push_error("ExhaustAction: Invalid target type")

func _exhaust_card(card: Card) -> void:
	if not card:
		return
	
	if not card_handler:
		push_error("ExhaustAction: card_handler not set")
		return
	
	# Remove from hand if it's there
	if card in card_handler.cards_in_hand:
		card_handler.cards_in_hand.erase(card)
		card_handler.card_position.erase(card)
	
	# Remove from draw pile if it's there
	if card in card_handler.draw_stack:
		card_handler.draw_stack.erase(card)
	
	# Remove from discard pile if it's there
	if card in card_handler.discard_stack:
		card_handler.discard_stack.erase(card)
	
	# Remove from scene tree
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	# Free the card - it's gone for this combat
	card.queue_free()
	
	# Rearrange remaining cards if in hand
	if card_handler:
		card_handler.arrange_cards()
	
	

func get_description_with_values(character: Character) -> String:
	if not character or not num_cards:
		return "Exhaust"
	
	var count = num_cards.calculate(character)
	
	match target_type:
		TargetType.CARD_IN_HAND:
			if count > 1:
				return "Exhaust §%d§ cards" % count
			else:
				return "Exhaust a card"
		TargetType.CARD_IN_DISCARD:
			if count > 1:
				return "Exhaust §%d§ cards from discard pile" % count
			else:
				return "Exhaust a card from discard pile"
		TargetType.CARD_IN_DRAW:
			if count > 1:
				return "Exhaust §%d§ cards from draw pile" % count
			else:
				return "Exhaust a card from draw pile"
		TargetType.RANDOM_CARD_IN_HAND:
			if count > 1:
				return "Exhaust §%d§ random cards" % count
			else:
				return "Exhaust a random card"
		TargetType.ALL_CARDS_IN_HAND:
			return "Exhaust all cards in hand"
	
	return "Exhaust"

# Helper to get random cards from hand
func get_random_cards_from_hand() -> Array[Card]:
	if not card_handler or not num_cards or not player:
		return []
	
	var cards: Array[Card] = []
	var available_cards = card_handler.cards_in_hand.duplicate()
	var count = num_cards.calculate(player)
	
	for i in min(count, available_cards.size()):
		if available_cards.is_empty():
			break
		var random_card = available_cards.pick_random()
		cards.append(random_card)
		available_cards.erase(random_card)
	
	return cards
