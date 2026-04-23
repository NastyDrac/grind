extends EventEffect
class_name EffectRemoveCard

## Opens the DeckViewer in SELECT mode.
## The player picks a card from their deck; that card is removed.


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	var unique_cards := _unique_deck(run_manager.deck)

	var viewer := DeckViewer.new()
	parent.add_child(viewer)
	viewer.setup(
		"Your Deck  —  %d cards" % run_manager.deck.size(),
		unique_cards,
		DeckViewer.Mode.SELECT,
		"Choose a card to remove:"
	)

	var _picked := false

	viewer.card_selected.connect(func(card_data: CardData) -> void:
		_picked = true
		var idx := run_manager.deck.find(card_data)
		if idx != -1:
			run_manager.deck.remove_at(idx)
		done.call()
	)

	viewer.closed.connect(func() -> void:
		if not _picked:
			done.call()
	)


func _unique_deck(deck: Array[CardData]) -> Array[CardData]:
	var seen := {}
	var result: Array[CardData] = []
	for card in deck:
		if not seen.has(card):
			seen[card] = true
			result.append(card)
	return result

func get_description(run : RunManager) -> String:
	return "Remove a card from your deck."
