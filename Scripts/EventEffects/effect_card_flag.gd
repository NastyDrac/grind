extends EventEffect
class_name EffectCardFlag

## Opens the DeckViewer in SELECT mode.
## The player picks a card; the chosen flag (Exhaust, Fickle, or Volatile)
## is set to [value] on that card.

enum Flag { EXHAUST, FICKLE, VOLATILE }

@export var flag: Flag = Flag.EXHAUST
## true = add the flag, false = remove it.
@export var value: bool = true


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	var viewer := DeckViewer.new()
	parent.add_child(viewer)
	viewer.setup(
		"Your Deck  —  %d cards" % run_manager.deck.size(),
		run_manager.deck,
		DeckViewer.Mode.SELECT,
		_prompt()
	)

	var _picked := false

	viewer.card_selected.connect(func(card_data: CardData) -> void:
		_picked = true
		match flag:
			Flag.EXHAUST:  card_data.exhaust  = value
			Flag.FICKLE:   card_data.fickle   = value
			Flag.VOLATILE: card_data.volatile  = value
		done.call()
	)

	viewer.closed.connect(func() -> void:
		if not _picked:
			done.call()
	)


func _prompt() -> String:
	var flag_name = ["Exhaust", "Fickle", "Volatile"][flag]
	var verb := "add" if value else "remove"
	return "Choose a card to %s %s:" % [verb, flag_name]


func get_description(run : RunManager) -> String:
	return _prompt()
