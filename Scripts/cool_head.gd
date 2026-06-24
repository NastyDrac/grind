extends ThingyCondition
class_name CoolHead

## "Cool Head" — the SILENT side of the loud/quiet dial. Discipline sharpens your
## aim: if you ended your LAST turn quiet (noise at or below `quiet_threshold`),
## your FIRST STRIKE this turn deals bonus damage (from `bonus_calc`), for the
## WHOLE card — every hit it makes (so all of Like a Shadow's hops get it).
##
## "Strike" = any card whose actions include an AttackAction (or a child of it,
## e.g. ShadowStrikeAction). Cards with no AttackAction never consume the buff, so
## it waits for your first real strike.
##
## The bonus is a ValueCalculator, evaluated against the player (entity), so it can
## be a flat number ("3") OR scale with anything the calculator knows — including
## noise. The silent fantasy reads naturally as a formula: e.g. "max(0, 6 - noise)"
## makes the bonus BIGGER the quieter you ended the turn. (Its loud counterpart,
## Headliner, would use the opposite slope, e.g. "floor(noise / 2)".)
##
## Spend is driven by the CARD, not the hit: _on_card_played spends once a card
## containing an attack resolves. Keying off the played card (rather than off
## modify() firing) means every Cool Head instance that hears card_played spends
## together — including the display-side instance — so the card face stays in sync
## with the damage.
##
## Works as a relic (special_effects) OR applied by a card: ThingyCondition routes
## apply_condition → setup() either way, and remove_condition → teardown() cleans up.

## End a turn at or below this noise level to arm next turn's first strike.
## THE MAIN TUNING KNOB — read it relative to the fight's passive_noise_per_turn.
@export var quiet_threshold : float = 6.0
## Bonus damage on every hit of your first strike after a quiet turn. Evaluated
## against the player, so it can read stats or noise. Set its formula to "3" for the
## old flat behaviour, or "max(0, 6 - noise)" to reward quieter turns more.
@export var bonus_calc : ValueCalculator


func setup(who, rm) -> void:
	super(who, rm)
	# Arm now if you're currently quiet: a relic at combat start (0 noise) arms
	# turn 1; a card played while disciplined arms this turn too.
	_armed = _is_quiet()
	_strikes_this_turn = 0
	if not Global.noise_settled.is_connected(_on_noise_settled):
		Global.noise_settled.connect(_on_noise_settled)
	if not Global.card_played.is_connected(_on_card_played):
		Global.card_played.connect(_on_card_played)


func teardown() -> void:
	if Global.noise_settled.is_connected(_on_noise_settled):
		Global.noise_settled.disconnect(_on_noise_settled)
	if Global.card_played.is_connected(_on_card_played):
		Global.card_played.disconnect(_on_card_played)
	super()


var _armed : bool = false
## Strikes (cards containing an AttackAction) played this turn. card_played fires
## when a card finishes, BEFORE its deferred damage lands, so counting here and
## gating on the count keeps the bonus live across every hit/hop of the FIRST
## strike card and drops it for the next one.
var _strikes_this_turn : int = 0


## Fired at the turn boundary with the turn's FULL noise (card costs + passive),
## captured before the meter drains. Arm next turn's first strike iff that total
## stayed at or under the threshold.
func _on_noise_settled(total_noise: float) -> void:
	_armed = total_noise <= quiet_threshold
	_strikes_this_turn = 0


func _on_card_played(card_data) -> void:
	# Tally strike cards. The first one (count becomes 1) is the one that gets the
	# bonus on all its hits; the second (count 2) no longer qualifies.
	if _card_is_strike(card_data):
		_strikes_this_turn += 1


## True if the card contains an AttackAction or any subclass of it.
func _card_is_strike(card_data) -> bool:
	if not card_data or not ("actions" in card_data):
		return false
	for a in card_data.actions:
		if a is AttackAction:
			return true
	return false


func _current_noise() -> float:
	if range_manager and ("noise_meter" in range_manager):
		return range_manager.noise_meter
	return 0.0


func _is_quiet() -> bool:
	return _current_noise() <= quiet_threshold


## The current bonus, evaluated against the player. Returns 0 when the calc isn't
## set or the player isn't in the tree yet (e.g. an out-of-combat preview), which
## keeps modify/preview safe to call every frame.
func _bonus() -> int:
	if bonus_calc and is_instance_valid(entity) and entity.is_inside_tree():
		return bonus_calc.calculate(entity)
	return 0


## PREVIEW (pure): show the boosted number only before any strike is played this
## turn, so the card you're about to play reads correctly and later cards don't.
func preview_outgoing_damage(damage: int, _target, _action) -> int:
	return damage + _bonus() if (_armed and _strikes_this_turn == 0) else damage


## APPLY (at execute): the FIRST strike card is in flight once its card_played has
## bumped the count to 1; every hit/hop of that card lands while the count is still
## 1, so they're all buffed. A later strike (count >= 2) gets nothing.
func modify_outgoing_damage(damage: int, _target, _action) -> int:
	if not (_armed and _strikes_this_turn <= 1):
		return damage
	return damage + _bonus()


func get_description_with_values() -> String:
	return "If you end a turn at %d Noise or less, your first strike next turn deals %s extra damage." % [
		int(quiet_threshold), _bonus_text()
	]


## Live number during combat; the raw formula out of context (shop / sheet) so a
## noise-scaling bonus still reads sensibly when there's no player to evaluate.
func _bonus_text() -> String:
	if bonus_calc and is_instance_valid(entity) and entity.is_inside_tree():
		return str(bonus_calc.calculate(entity))
	if bonus_calc:
		return bonus_calc.formula
	return "0"
