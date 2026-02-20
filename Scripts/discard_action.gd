extends Action
class_name DiscardAction

# Discard mechanic: Move card(s) to discard pile
# Discarded cards can be shuffled back when draw pile is empty

# Number of cards to discard (uses ValueCalculator for dynamic values)
@export var num_cards: ValueCalculator

func get_action_type() -> String:
	return "Discard"

func execute(target) -> void:
	# Target can be a Card or an Array[Card]
	if target is Array:
		for card in target:
			_discard_card(card)
	elif target is Card:
		_discard_card(target)
	else:
		push_error("DiscardAction: Invalid target type")

func _discard_card(card: Card) -> void:
	if not card:
		return
	
	if not card_handler:
		push_error("DiscardAction: card_handler not set")
		return
	
	# Card should already be in hand (we're executing after target collection)
	if card not in card_handler.cards_in_hand:
		push_warning("DiscardAction: Card '%s' is not in hand" % card.data.card_name)
		return
	
	
	
	# Remove from hand
	card_handler.cards_in_hand.erase(card)
	card_handler.card_position.erase(card)
	
	# Move directly to discard pile without animation (we're in batch execution)
	card.reparent(card_handler.discard_pile)
	card.global_position = card_handler.discard_pile.global_position
	

func get_description_with_values(character: Character) -> String:
	if not character or not num_cards:
		return "Discard"
	
	var count = num_cards.calculate(character)
	
	match target_type:
		TargetType.CARD_IN_HAND:
			if count > 1:
				return "Discard §%d§ cards" % count
			else:
				return "Discard a card"
		TargetType.RANDOM_CARD_IN_HAND:
			if count > 1:
				return "Discard §%d§ random cards" % count
			else:
				return "Discard a random card"
		TargetType.ALL_CARDS_IN_HAND:
			return "Discard all cards in hand"
	
	return "Discard"

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
