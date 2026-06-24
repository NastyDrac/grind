extends Action
class_name DropItemAction

## Drops any item onto the battlefield. Generic on purpose: assign whichever
## ItemData you want (Scrap, Gold, …) and it spawns into the range system just
## like an enemy death-drop, so it still has to travel in to be collected.

## Which item to drop. Assign the Scrap ItemData for a salvage card.
@export var item: ItemData

## How many to drop. Leave null for 1; use a formula to scale (e.g. off a stat).
@export var amount_calculator: ValueCalculator

## Where the drop lands:
##   true  → at the targeted enemy's range (Strip Parts: salvage what you hit).
##           Falls back to fixed_range if the target is gone (e.g. the hit killed it).
##   false → at fixed_range, measured from the player.
@export var drop_at_target_range: bool = true

## Range used when drop_at_target_range is false (or as the fallback). 1 = lands
## next turn; higher = takes longer to walk in.
@export var fixed_range: int = 1


func get_action_type() -> String:
	return "Drop Item"


# ─────────────────────────────────────────────
# EXECUTE  (target = the reused enemy for a salvage card, or the player for SELF)
# ─────────────────────────────────────────────

func execute(target) -> void:
	if not item:
		push_warning("DropItemAction: no item assigned.")
		return

	var rm := _range_manager()
	if not rm:
		push_warning("DropItemAction: no range_manager accessible from player.")
		return

	# Where to spawn. Default to the fixed range; if we're salvaging from a live
	# enemy, use its range instead. (Vector2.ZERO position lets the range manager
	# slot the items neatly so multiples don't stack on one pixel.)
	var at_range : int = fixed_range
	if drop_at_target_range and is_instance_valid(target) and target is Enemy:
		at_range = target.get_current_range()
	at_range = maxi(0, at_range)

	for i in _amount(player):
		rm.spawn_item(item, at_range, Vector2.ZERO)


func _amount(who) -> int:
	if amount_calculator and who:
		return maxi(0, amount_calculator.calculate(who))
	return 1


func _amount_formula() -> String:
	return amount_calculator.formula if amount_calculator else ""


func _range_manager() -> RangeManager:
	if player and player.run_manager:
		return player.run_manager.range_manager
	return null


# ─────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────

func get_card_text(character) -> String:
	var who = character if character else player
	var n = _amount(who)
	var item_name : String = item.item_name if item else "item"
	if drop_at_target_range:
		return "Salvage %s %s" % [_cv(n, _amount_formula()), item_name]
	return "Drop %s %s at range %s" % [_cv(n, _amount_formula()), item_name, _cv(fixed_range)]


## Hover tooltip: shows the formula behind the amount when it's a calculation
## (e.g. "3 dropped = heat / 2"); empty for a flat literal. Plain text.
func get_tooltip_text(character) -> String:
	if not amount_calculator:
		return ""
	var who = character if character else player
	if not who:
		return ""
	return _formula_breakdown("dropped", amount_calculator.calculate(who), amount_calculator.formula)
