extends EventEffect
class_name EffectAddAction

## Appends [action] to a card's actions array.
##  - random_cards = false: opens the DeckViewer SELECT [count] times; player picks.
##  - random_cards = true:  applies to [count] RANDOM, distinct cards from the deck
##    with no picker (the Whetstone "you don't choose what it sharpens" option).
@export var action: Action = null
@export var count : int = 1
## Apply to random cards instead of letting the player choose.
@export var random_cards : bool = false


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	if action == null:
		push_warning("EffectAddAction: no action assigned.")
		done.call()
		return

	if random_cards:
		_apply_random(run_manager)
		done.call()
		return

	var provider := func() -> Array[CardData]:
		return run_manager.deck

	var on_pick := func(card_data: CardData) -> void:
		card_data.actions.append(action)

	_select_cards(run_manager, parent, count, "Choose a card to add an action to:", provider, on_pick, done)


## Append a fresh copy of [action] to up to [count] distinct random cards. Each
## card gets its own duplicate so they don't share one Action instance. Uses the
## seeded run RNG so a given seed replays identically.
func _apply_random(run_manager: RunManager) -> void:
	var pool : Array = run_manager.deck.duplicate()
	if pool.is_empty():
		return
	var n : int = mini(maxi(1, count), pool.size())
	for k in n:
		var idx : int = _roll(run_manager, pool.size())
		pool[idx].actions.append(action.duplicate(true))
		pool.remove_at(idx)   # distinct cards: don't sharpen the same one twice


func _roll(run_manager: RunManager, upper: int) -> int:
	if run_manager and run_manager.rng:
		return run_manager.rng.randi_range(0, upper - 1)
	return randi() % upper


func get_description(run : RunManager) -> String:
	var what := "(" + action.get_description_with_values(run.player) + ")"
	if random_cards:
		return "Add %s to %d random card(s)" % [what, maxi(1, count)]
	if count <= 1:
		return "Add %s to a card" % what
	return "Add %s to up to %d cards" % [what, count]
