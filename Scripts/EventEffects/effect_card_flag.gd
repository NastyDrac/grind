extends EventEffect
class_name EffectCardFlag

## Opens the DeckViewer in SELECT mode, [count] times in a row.
## Each pick sets the chosen flag (Exhaust, Fickle, or Volatile) to [value] on
## that card; the player can Skip to stop early.

enum Flag { EXHAUST, FICKLE, VOLATILE }

@export var flag: Flag = Flag.EXHAUST
## true = add the flag, false = remove it.
@export var value: bool = true
@export var count : int = 1


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	var provider := func() -> Array[CardData]:
		return run_manager.deck

	var on_pick := func(card_data: CardData) -> void:
		match flag:
			Flag.EXHAUST:  card_data.exhaust  = value
			Flag.FICKLE:   card_data.fickle   = value
			Flag.VOLATILE: card_data.volatile = value

	_select_cards(run_manager, parent, count, _prompt(), provider, on_pick, done)


func _prompt() -> String:
	var flag_name = ["Exhaust", "Fickle", "Volatile"][flag]
	var verb := "add" if value else "remove"
	return "Choose a card to %s %s:" % [verb, flag_name]


func get_description(run : RunManager) -> String:
	return _prompt()
