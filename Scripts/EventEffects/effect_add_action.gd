extends EventEffect
class_name EffectAddAction

## Opens the DeckViewer in SELECT mode.
## The player picks a card; [action] is appended to that card's actions array.
@export var action: Action = null


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	if action == null:
		push_warning("EffectAddAction: no action assigned.")
		done.call()
		return

	var viewer := DeckViewer.new()
	parent.add_child(viewer)
	viewer.setup(
		"Your Deck  —  %d cards" % run_manager.deck.size(),
		run_manager.deck,
		DeckViewer.Mode.SELECT,
		"Choose a card to add an action to:"
	)

	var _picked := false

	viewer.card_selected.connect(func(card_data: CardData) -> void:
		_picked = true
		card_data.actions.append(action)
		done.call()
	)

	viewer.closed.connect(func() -> void:
		if not _picked:
			done.call()
	)


func get_description(run : RunManager) -> String:
	return "Add (" + action.get_description_with_values(run.player) + ") to a card"
