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
	_spent_this_turn = false
	if not Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.connect(_on_time_passed)
	if not Global.card_played.is_connected(_on_card_played):
		Global.card_played.connect(_on_card_played)


func teardown() -> void:
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
	if Global.card_played.is_connected(_on_card_played):
		Global.card_played.disconnect(_on_card_played)
	super()


var _armed : bool = false
var _spent_this_turn : bool = false


func _on_time_passed() -> void:
	# Re-evaluate at every turn boundary: a quiet turn arms next turn's first
	# strike, a loud turn clears it; reset the per-turn spend flag.
	_armed = _is_quiet()
	_spent_this_turn = false


func _on_card_played(card_data) -> void:
	# Spend once the first STRIKE card resolves. A strike is any card carrying an
	# AttackAction (or child); non-attacks leave the buff armed for a later strike.
	if _armed and not _spent_this_turn and _card_is_strike(card_data):
		_spent_this_turn = true


## True if the card contains an AttackAction or any subclass of it.
func _card_is_strike(card_data) -> bool:
	if not card_data or not ("actions" in card_data):
		return false
	for a in card_data.actions:
		if a is AttackAction:
			return true
	return false


func _is_quiet() -> bool:
	if range_manager and ("noise_meter" in range_manager):
		return range_manager.noise_meter <= quiet_threshold
	return false


func _buff_live() -> bool:
	return _armed and not _spent_this_turn


## The current bonus, evaluated against the player. Returns 0 when the calc isn't
## set or the player isn't in the tree yet (e.g. an out-of-combat preview), which
## keeps modify/preview safe to call every frame.
func _bonus() -> int:
	if bonus_calc and is_instance_valid(entity) and entity.is_inside_tree():
		return bonus_calc.calculate(entity)
	return 0


## PREVIEW (pure): strike cards preview the boosted number while the buff is live;
## once a strike is played, every card reads base on the next render.
func preview_outgoing_damage(damage: int, _target, _action) -> int:
	return damage + _bonus() if _buff_live() else damage


## APPLY (at execute): same bonus on every hit while live. The spend happens in
## _on_card_played, so the whole strike card — every Like a Shadow hop — is buffed.
func modify_outgoing_damage(damage: int, _target, _action) -> int:
	return damage + _bonus() if _buff_live() else damage


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
