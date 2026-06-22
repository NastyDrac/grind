extends EventEffect
class_name EffectAddAction

## Opens the DeckViewer in SELECT mode, [count] times in a row.
## Each pick appends [action] to that card's actions array; Skip stops early.
@export var action: Action = null
@export var count : int = 1


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	if action == null:
		push_warning("EffectAddAction: no action assigned.")
		done.call()
		return

	var provider := func() -> Array[CardData]:
		return run_manager.deck

	var on_pick := func(card_data: CardData) -> void:
		card_data.actions.append(action)

	_select_cards(run_manager, parent, count, "Choose a card to add an action to:", provider, on_pick, done)


func get_description(run : RunManager) -> String:
	var what := "(" + action.get_description_with_values(run.player) + ")"
	if count <= 1:
		return "Add %s to a card" % what
	return "Add %s to up to %d cards" % [what, count]
