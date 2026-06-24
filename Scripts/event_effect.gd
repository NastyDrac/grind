extends Resource
class_name EventEffect

var run_manager : RunManager
## Base class for all event option effects.
##
## Each effect implements execute(), which receives the RunManager, the parent
## Node to attach any UI to (always the EventScene), and a Callable to invoke
## when the effect is finished so the queue can advance.
##
## Instant effects apply their change and call done immediately.
## Async effects (card selection, draft) open their own UI, wait for input,
## apply, then call done.

func execute(_run_manager: RunManager, _parent: Node, done: Callable) -> void:
	run_manager = _run_manager
	done.call()

func get_description(run : RunManager) -> String:
	return ""


# ── Hover hooks for the event option button (both optional) ───────────────────
## A card to render a copy of when the player hovers the option (add-card
## effects return their CardData). Null = no card preview.
func get_preview_card() -> CardData:
	return null

## Plain-text hover tooltip for the option (e.g. a relic's name + description).
## "" = no text tooltip.
func get_tooltip_text() -> String:
	return ""


# ── Shared multi-pick helper ──────────────────────────────────────────────────
## Opens the DeckViewer in SELECT mode up to [count] times, invoking [on_pick]
## with each chosen card. The player can Skip to end early. [cards_provider] is
## called before EACH round and returns the current card list, so effects that
## mutate the deck between picks (e.g. removal) always show fresh data. [done] is
## called exactly once, after the final pick, an early skip, or when no cards
## remain. Effects that act on one card just pass count = 1.
func _select_cards(run : RunManager, parent : Node, count : int, prompt : String,
		cards_provider : Callable, on_pick : Callable, done : Callable) -> void:
	_open_select_round(run, parent, maxi(1, count), prompt, cards_provider, on_pick, done)


## One round of _select_cards. Recurses (by name, so it survives — GDScript
## lambdas can't reference themselves) for the next pick.
func _open_select_round(run : RunManager, parent : Node, left : int, prompt : String,
		cards_provider : Callable, on_pick : Callable, done : Callable) -> void:
	var cards : Array[CardData] = cards_provider.call()
	if left <= 0 or cards.is_empty():
		done.call()
		return

	var viewer := DeckViewer.new()
	parent.add_child(viewer)
	viewer.setup(
		"Your Deck  —  %d cards" % run.deck.size(),
		cards,
		DeckViewer.Mode.SELECT,
		prompt
	)

	# Dictionary (reference type) so the closed-handler lambda sees the flip the
	# card_selected handler makes. Selecting fires BOTH signals, so the guard
	# stops a skipped-only `done` from also running on a real pick.
	var picked := {"v": false}

	viewer.card_selected.connect(func(card_data: CardData) -> void:
		picked["v"] = true
		on_pick.call(card_data)
		_open_select_round(run, parent, left - 1, prompt, cards_provider, on_pick, done)
	)

	viewer.closed.connect(func() -> void:
		if not picked["v"]:
			done.call()
)
