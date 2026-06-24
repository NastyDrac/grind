extends EventEffect
class_name EffectAddCard

## Immediately adds [count] copies of [card] to the player's deck.
@export var card: CardData = null
@export var count : int = 1


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	if card == null:
		push_warning("EffectAddCard: no card assigned.")
	else:
		for i in maxi(1, count):
			run_manager.add_card_to_deck(card)
	done.call()

func get_description(run : RunManager) -> String:
	if card == null:
		return ""
	if count <= 1:
		return "Add %s to your deck." % card.card_name
	return "Add %d copies of %s to your deck." % [count, card.card_name]


## Show a copy of the card being added when the player hovers this option.
func get_preview_card() -> CardData:
	return card
