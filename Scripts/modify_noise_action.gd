extends Action
class_name ModifyNoiseAction

## Lets a CARD change the RangeManager's noise meter — the first time the player
## (not just enemies) becomes a noise actor.
##
## Two modes:
##   • set_to_zero = true   → dump the meter to 0 ("vent"). Pair with an
##     AttackAction whose damage formula is "noise" placed BEFORE this action in
##     the card's `actions` array, so the attack captures the meter and THEN it
##     empties. (Actions resolve top-to-bottom.)
##   • set_to_zero = false  → add amount_calculator to the meter. Use a negative
##     formula (e.g. "-3") for a "quiet" card that buys breathing room, or a
##     positive one for a high-risk card that's cheap now but spikes the threat.
##
## The meter is the single source of truth for spawns, so lowering it delays the
## next wave and raising it pulls the next wave forward — no extra plumbing
## needed. amount_calculator may reference `noise` itself (e.g. "noise / 2" to
## halve the meter).

@export var set_to_zero : bool = false
@export var amount_calculator : ValueCalculator

func get_action_type() -> String:
	return "Modify Noise"

func execute(_target) -> void:
	if not player:
		push_error("ModifyNoiseAction requires a valid player")
		return
	var rm = _range_manager()
	if rm == null:
		push_warning("ModifyNoiseAction: no RangeManager found; nothing to do.")
		return

	if set_to_zero:
		rm.noise_meter = 0.0
	else:
		if amount_calculator:
			rm.noise_meter += float(amount_calculator.calculate(player))
		rm.noise_meter = maxf(rm.noise_meter, 0.0)

	# Refresh the on-screen meter immediately if the manager exposes a redraw.
	if rm.has_method("_update_noise_display"):
		rm._update_noise_display()

func _range_manager():
	if player and player.is_inside_tree():
		return player.get_tree().get_first_node_in_group("range_manager")
	return null


# ============================================================================
# DESCRIPTION
# ============================================================================

func get_description_with_values(character) -> String:
	if set_to_zero:
		return "Set Noise to 0"
	if not character or not amount_calculator:
		return "Modify Noise"
	var amount = amount_calculator.calculate(character)
	var formula = amount_calculator.formula
	var verb := "Raise" if amount >= 0 else "Lower"
	if formula.is_valid_int():
		return "%s Noise by %d" % [verb, abs(amount)]
	return "%s Noise by §%d§ (%s)" % [verb, abs(amount), _format_formula_display(formula)]

func get_card_text(character) -> String:
	if set_to_zero:
		return "Set Noise to %s" % _cv(0)
	if not character or not amount_calculator:
		return "Modify Noise"
	var amount = amount_calculator.calculate(character)
	var verb := "Raise" if amount >= 0 else "Lower"
	return "%s Noise by %s" % [verb, _cv(abs(amount), amount_calculator.formula)]

func get_tooltip_text(character) -> String:
	if set_to_zero or not character or not amount_calculator:
		return ""
	if amount_calculator.formula.is_valid_int():
		return ""
	var amount = amount_calculator.calculate(character)
	return "%d noise = %s" % [abs(amount), _format_formula_display(amount_calculator.formula)]
