extends ThingyCondition
class_name Momentum

## Momentum — the Drifter's signature passive (Hustle / Mojo archetype).
##
## Every card you play THIS TURN grants +1 Mojo. The bonus is refunded when you
## pass time (Global.time_passed), so it never carries into the enemy turn or the
## next one — it's a per-turn ramp, not a fight-long snowball. Play cheap Hustle
## cards first to pump Mojo, THEN drop a Mojo finisher in the same turn. "Trust
## the energy" — but only while it's hot.
##
## Mirrors NewtonsCradle: lives in special_effects, hooks global signals in
## setup() and unhooks in teardown(). It mutates the player's COMBAT copy of the
## Mojo stat, and only ever removes exactly what it added.

@export var mojo_per_card : int = 1

## Raw Mojo this passive has added during the current turn (refunded at turn end).
var _added_this_turn : int = 0

func setup(who, rm) -> void:
	super(who, rm)
	show_stacks = true
	stacks = 0
	_added_this_turn = 0
	if not Global.card_played.is_connected(_on_card_played):
		Global.card_played.connect(_on_card_played)
	if not Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.connect(_on_time_passed)

func teardown() -> void:
	if Global.card_played.is_connected(_on_card_played):
		Global.card_played.disconnect(_on_card_played)
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
	super()

func _on_card_played(_card_data) -> void:
	var mojo := _mojo_stat()
	if mojo == null:
		return
	mojo.modify_stat(mojo_per_card)
	_added_this_turn += mojo_per_card
	stacks = _added_this_turn   # ConditionIcon polls this — Mojo banked this turn

## End of turn: hand back exactly what we granted, so Mojo returns to its base
## (plus any PERMANENT gains from cards like Lucky Coin / All In, which we never
## touched).
func _on_time_passed() -> void:
	if _added_this_turn == 0:
		return
	var mojo := _mojo_stat()
	if mojo:
		mojo.modify_stat(-_added_this_turn)
	_added_this_turn = 0
	stacks = 0

func _mojo_stat() -> Stat:
	if not entity or not is_instance_valid(entity):
		return null
	for stat in entity.stats:
		if stat.stat_type == Stat.STAT.MOJO:
			return stat
	return null

func get_description_with_values() -> String:
	return "Each card you play this turn grants +%d Mojo. Resets when you pass time." % mojo_per_card
