extends AttackAction
class_name ShadowStrikeAction

## "Like a Shadow" — a single-target strike that lets you pick a NEW target and
## strike again every time the blow is lethal. Damage itself is identical to a
## normal AttackAction; the chaining lives in the card handler, which checks
## chains_on_kill() and re-opens targeting after a kill. The fantasy: flit from
## body to body so long as each cut is clean.
##
## Design notes:
##   • This should be a card's ONLY action. The chain resolves interactively and
##     immediately, so a trailing action would sequence awkwardly.
##   • target_type MUST be SINGLE_ENEMY. The chain picks one new target per hop.
##   • Set animation_type = MELEE_SLASH in the inspector even at range 5 — the
##     ninja closes the gap each strike.

## The card handler reads this to route the action through its chain loop.
func chains_on_kill() -> bool:
	return true


## One target per hop, always.
func get_num_targets(_character: Character) -> int:
	return 1


## Concise card body: damage plus the one-line chain clause. Uses the inherited
## _previewed_damage() so buff conditions (Cool Head, etc.) show on the card face
## here exactly as they do on a plain attack — the chain's first hit is buffed.
func get_card_text(character) -> String:
	if not character or not damage_calculator:
		return "Deal damage. On kill, strike again."
	var dmg = _previewed_damage(character)
	return "Deal %s damage. On kill, strike again." % _cv(dmg, damage_calculator.formula)


func get_description_with_values(character: Character) -> String:
	if not character or not damage_calculator:
		return "Deal damage. On kill, strike again."
	var dmg = damage_calculator.calculate(character)
	var formula = damage_calculator.formula
	if formula.is_valid_int():
		return "Deal %d damage. On kill, strike again." % dmg
	return "Deal §%d§ damage (%s). On kill, strike again." % [dmg, _format_formula_display(formula)]
