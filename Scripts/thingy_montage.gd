extends ThingyCondition
class_name ThingyMontage

## "Training Montage" — gain +1 to a RANDOM stat each time a card is added to
## your deck.
##
## This is a RUN-level listener (cards are added between combats), so it connects
## in activate() — which fires for both starting passives and mid-run pickups —
## NOT in on_pickup or setup. deactivate() disconnects at run end.

@export var amount : int = 1

var _run

func activate(run) -> void:
	_run = run
	if not Global.card_added_to_deck.is_connected(_on_card_added):
		Global.card_added_to_deck.connect(_on_card_added)

func deactivate() -> void:
	if Global.card_added_to_deck.is_connected(_on_card_added):
		Global.card_added_to_deck.disconnect(_on_card_added)
	_run = null

func _on_card_added(_card) -> void:
	if _run == null or _run.character == null or _run.character.stats.is_empty():
		return
	var stat = _run.character.stats.pick_random()
	stat.modify_stat(amount)
	if _run.player and _run.player.has_method("sync_from_data"):
		_run.player.sync_from_data()

func get_description_with_values() -> String:
	return "Whenever a card is added to your deck, gain %d to a random stat." % amount
