extends ThingyCondition
class_name Headliner

## "Headliner" — the LOUD side of the noise dial, and the reactive mirror of Cool
## Head. Whenever you play a card costing `cost_threshold` or more, you gain block
## (from `block_calc`). Loud = expensive cards = noise = a bigger crowd, so this
## hands loud its compensating reward: armor to tank the swarm it summons.
##
## The block amount is a ValueCalculator evaluated against the player (entity), so
## it can be flat ("5") OR scale with the loud you're generating — e.g.
## "floor(noise / 2)" pays more the louder you've been, or "enemies" pays for the
## crowd actually on the board. (Cool Head's bonus uses the opposite slope.)
##
## Same ThingyCondition skeleton as Cool Head, so it works BOTH ways with no code
## change: drop it in player.special_effects for a permanent relic (reset_for_new_
## wave re-runs setup every fight), or apply it from a card via ApplyConditionAction
## for a per-fight setup. Pick at the granting level; the script doesn't care.

## Minimum card cost that triggers the block. "2+" by default — i.e. only cards
## loud enough to matter pay out, so cheap chip cards don't farm armor.
@export var cost_threshold : int = 2
## Block granted per qualifying card. Evaluated against the player, so it can read
## stats or noise. "5" for flat; "floor(noise / 2)" or "enemies" to scale with loud.
@export var block_calc : ValueCalculator


func setup(who, rm) -> void:
	super(who, rm)
	if not Global.card_played.is_connected(_on_card_played):
		Global.card_played.connect(_on_card_played)


func teardown() -> void:
	if Global.card_played.is_connected(_on_card_played):
		Global.card_played.disconnect(_on_card_played)
	super()


func _on_card_played(card_data) -> void:
	# Reads the card's BASE cost (card_played only carries the CardData, not the
	# in-hand Card with its runtime cost modifiers). Good enough for "is this an
	# expensive card"; revisit if cost-reduction builds need the actual paid cost.
	if not card_data or not ("card_cost" in card_data):
		return
	if card_data.card_cost < cost_threshold:
		return
	var amount := _block()
	if amount > 0 and is_instance_valid(entity):
		entity.gain_block(amount)


## The block amount, evaluated against the player. Returns 0 when the calc isn't
## set or the player isn't in the tree yet, so the trigger is always safe to fire.
func _block() -> int:
	if block_calc and is_instance_valid(entity) and entity.is_inside_tree():
		return block_calc.calculate(entity)
	return 0


func get_description_with_values() -> String:
	return "Whenever you play a card costing %d or more, gain %s Block." % [
		cost_threshold, _block_text()
	]


## Live number during combat; the raw formula out of context (shop / sheet) so a
## noise-scaling amount still reads sensibly when there's no player to evaluate.
func _block_text() -> String:
	if block_calc and is_instance_valid(entity) and entity.is_inside_tree():
		return str(block_calc.calculate(entity))
	if block_calc:
		return block_calc.formula
	return "0"
