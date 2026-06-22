extends EventEffect
class_name EffectRemoveCard

## Opens the DeckViewer in SELECT mode, [count] times in a row.
## Each pick removes one card from the deck; the player can Skip to stop early.
@export var count : int = 1


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	# Fresh unique list each round, so removed cards drop out of the picker.
	var provider := func() -> Array[CardData]:
		return _unique_deck(run_manager.deck)

	var on_pick := func(card_data: CardData) -> void:
		var idx := run_manager.deck.find(card_data)
		if idx != -1:
			run_manager.deck.remove_at(idx)

	_select_cards(run_manager, parent, count, "Choose a card to remove:", provider, on_pick, done)


func _unique_deck(deck: Array[CardData]) -> Array[CardData]:
	var seen := {}
	var result: Array[CardData] = []
	for card in deck:
		if not seen.has(card):
			seen[card] = true
			result.append(card)
	return result

func get_description(run : RunManager) -> String:
	if count <= 1:
		return "Remove a card from your deck."
	return "Remove up to %d cards from your deck." % count
