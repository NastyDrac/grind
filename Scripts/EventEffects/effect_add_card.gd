extends EventEffect
class_name EffectAddCard

## Immediately adds a specific card to the player's deck.
@export var card: CardData = null


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	if card == null:
		push_warning("EffectAddCard: no card assigned.")
	else:
		run_manager.deck.append(card)
	done.call()

func get_description(run : RunManager) -> String:
	return str("Add " + card.card_name + " to your deck.")
