extends Resource
class_name ValueCalculator

@export_multiline var formula: String = "swag"


var _expression: Expression = null
var _compiled: bool = false
## Set when the formula references a token that isn't a recognised input. We
## then skip execution entirely (returning 0) so a typo'd formula doesn't spam
## the engine with a "self is null" error every frame from card previews.
var _invalid: bool = false

## The only identifiers a formula may use. Anything else is treated by Expression
## as a member of a (null) base instance and fails — so we catch it up front.
##
## Battlefield tokens:
##   block   — the player's current block
##   enemies — count of living enemies on the field
##   here    — enemies at the range currently being aimed at
##   noise   — the current value of the RangeManager noise meter (rounded down)
##   burn    — Burning stacks on the enemy currently being aimed at
const _ALLOWED_TOKENS := ["swag", "guts", "heat", "hustle", "marbles", "mojo", "block", "enemies", "here", "noise", "burn"]

## Order MUST match the names passed to Expression.parse() and the values passed
## to Expression.execute(). Keep these three lists in lock-step.
const _INPUT_NAMES := ["swag", "guts", "heat", "hustle", "marbles", "mojo", "block", "enemies", "here", "noise", "burn"]

func calculate(player : Character) -> int:
	if not player:
		return 0
	
	return _calculate_formula(player)


## Returns a human-readable version of the formula for card descriptions.
## Converts decimal multipliers to percentages, e.g.:
##   "0.25 * swag"  ->  "25% swag"
##   "swag * 0.5"   ->  "50% swag"
##   "swag + guts"  ->  "swag + guts"  (unchanged)
func get_formula_display() -> String:
	var display = formula
	var regex = RegEx.new()

	# Pattern: 0.XX * stat_name  (decimal first)
	regex.compile("(\\d*\\.\\d+)\\s*\\*\\s*(swag|guts|heat|hustle|marbles|mojo)")
	var match_result = regex.search(display)
	while match_result:
		var pct = int(round(float(match_result.get_string(1)) * 100.0))
		var stat = match_result.get_string(2)
		display = (display.substr(0, match_result.get_start())
				+ str(pct) + "% " + stat
				+ display.substr(match_result.get_end()))
		match_result = regex.search(display)

	# Pattern: stat_name * 0.XX  (stat first)
	regex.compile("(swag|guts|heat|hustle|marbles|mojo)\\s*\\*\\s*(\\d*\\.\\d+)")
	match_result = regex.search(display)
	while match_result:
		var stat = match_result.get_string(1)
		var pct = int(round(float(match_result.get_string(2)) * 100.0))
		display = (display.substr(0, match_result.get_start())
				+ str(pct) + "% " + stat
				+ display.substr(match_result.get_end()))
		match_result = regex.search(display)

	return display


func _calculate_formula(player : Character) -> int:
	
	if not _compiled:
		_compile_expression()
	
	if _invalid:
		return 0  # known-bad formula — don't execute (would spam the engine)
	
	if not _expression:
		push_error("Expression failed to compile")
		return 0
	
	# Cast stats to float so division produces correct results.
	# Without this, GDScript integer division truncates: e.g. 3/5 = 0 instead of 0.6.
	var swag_stat    = float(_find_stat_from_character(player, Stat.STAT.SWAG))
	var guts_stat    = float(_find_stat_from_character(player, Stat.STAT.GUTS))
	var heat_stat    = float(_find_stat_from_character(player, Stat.STAT.HEAT))
	var hustle_stat  = float(_find_stat_from_character(player, Stat.STAT.HUSTLE))
	var marbles_stat = float(_find_stat_from_character(player, Stat.STAT.MARBLES))
	var mojo_stat    = float(_find_stat_from_character(player, Stat.STAT.MOJO))
	
	# Battlefield-aware inputs. `block` reads the player's current block;
	# `enemies` is the count of living enemies on the field. Both default to 0
	# outside combat (previews, gym) so existing formulas are unaffected.
	var block_val    = float(player.block) if player else 0.0
	var enemy_count  = float(_get_enemy_count(player))
	# `here` = enemies at the range currently being aimed at with the mouse.
	var here_count   = float(_get_enemies_at_targeted_range(player))
	# `noise` = current meter value (floored); `burn` = Burning on the aimed
	# enemy. Both read 0 outside combat / before a target is chosen, so in-hand
	# previews stay safe exactly like `here`.
	var noise_val    = float(_get_noise(player))
	var burn_val     = float(_get_burn_on_target(player))
	
	var result = _expression.execute([swag_stat, guts_stat, heat_stat, hustle_stat, marbles_stat, mojo_stat, block_val, enemy_count, here_count, noise_val, burn_val])
	
	if _expression.has_execute_failed():
		push_error("Expression execution failed: %s" % _expression.get_error_text())
		return 0
	
	return int(round(result))

func _find_stat_from_character(player: Character, stat_type: Stat.STAT) -> int:
	for stat in player.stats:
		if stat.stat_type == stat_type:
			return stat.value
	return 0

## Count of living enemies currently on the field, read from the RangeManager's
## authoritative collection. Returns 0 if the player isn't in a combat scene
## (e.g. character-select preview), which keeps non-combat formulas safe.
func _get_enemy_count(player: Character) -> int:
	if not player or not player.is_inside_tree():
		return 0
	var rm = player.get_tree().get_first_node_in_group("range_manager")
	if rm == null or not rm.has_method("get_all_enemies"):
		return 0
	return rm.get_all_enemies().size()

func _compile_expression() -> void:
	_expression = Expression.new()
	_invalid = false

	# Catch unknown identifiers up front. Any alpha word that isn't a known input
	# would be read as self.<word>, fail at execute, and spam an error every
	# frame from in-hand card previews. Warn once here and mark the calc invalid.
	var ident := RegEx.new()
	ident.compile("[A-Za-z_][A-Za-z0-9_]*")
	for m in ident.search_all(formula):
		if not _ALLOWED_TOKENS.has(m.get_string()):
			push_error("ValueCalculator: unknown token '%s' in formula '%s'. Valid tokens: swag, guts, heat, hustle, marbles, mojo, block, enemies, here, noise, burn." % [m.get_string(), formula])
			_invalid = true

	# Parse with variable names as input
	var error = _expression.parse(formula, _INPUT_NAMES)
	
	if error != OK:
		push_error("Failed to parse formula '%s': %s" % [formula, _expression.get_error_text()])
		_expression = null
	
	_compiled = true

## Count of living enemies at the range the player is currently aiming at (the
## RangeManager updates `targeted_range` live during targeting and holds it
## through execution). Returns 0 when nothing is being aimed at — so in-hand
## previews of a `here` formula read 0 until the player actually targets.
func _get_enemies_at_targeted_range(player: Character) -> int:
	if not player or not player.is_inside_tree():
		return 0
	var rm = player.get_tree().get_first_node_in_group("range_manager")
	if rm == null or not ("targeted_range" in rm) or not rm.has_method("get_enemies_at_range"):
		return 0
	var r : int = rm.targeted_range
	if r < 0:
		return 0
	var arr = rm.get_enemies_at_range(r)
	if arr == null:
		return 0
	var c := 0
	for e in arr:
		if is_instance_valid(e):
			c += 1
	return c

## Current noise meter value, floored to an int so formulas read it as a clean
## number. Returns 0 outside combat (no RangeManager), keeping previews safe.
func _get_noise(player: Character) -> int:
	if not player or not player.is_inside_tree():
		return 0
	var rm = player.get_tree().get_first_node_in_group("range_manager")
	if rm == null or not ("noise_meter" in rm):
		return 0
	return int(floor(rm.noise_meter))

## Burning stacks on the enemy the player is currently aiming at. Reads the
## hovered enemy first (single-target detonators); if no single enemy is hovered
## but a range is targeted, sums Burning across that range. Returns 0 before a
## target is chosen, so in-hand previews show 0 until the player aims.
func _get_burn_on_target(player: Character) -> int:
	if not player or not player.is_inside_tree():
		return 0
	var rm = player.get_tree().get_first_node_in_group("range_manager")
	if rm == null:
		return 0

	# Prefer the single hovered enemy.
	if ("enemy_hovered" in rm) and is_instance_valid(rm.enemy_hovered):
		return _burning_stacks_on(rm.enemy_hovered)

	# Fall back to the aimed range (AoE-style aiming).
	if ("targeted_range" in rm) and rm.has_method("get_enemies_at_range"):
		var r : int = rm.targeted_range
		if r >= 0:
			var total := 0
			for e in rm.get_enemies_at_range(r):
				if is_instance_valid(e):
					total += _burning_stacks_on(e)
			return total
	return 0

func _burning_stacks_on(who) -> int:
	if not who or not ("conditions" in who):
		return 0
	for cond in who.conditions:
		if cond is Burning:
			return cond.stacks
	return 0


# ─── Workshop support ───────────────────────────────────────────────────────────

## The stats the Workshop can retune to, in display order.
const STAT_TOKENS : Array = ["swag", "marbles", "guts", "heat", "hustle", "mojo"]

## Handle for one editable value in the formula. Exposes `.text` (what the
## Workshop reads) plus the character span so retune_token() can splice.
class FormulaToken:
	var text  : String
	var start : int
	var end   : int
	func _init(t: String, s: int, e: int) -> void:
		text = t
		start = s
		end = e

## Build a "stat1|stat2|..." alternation without String.join (unreliable on a
## const Array).
func _stat_alternation() -> String:
	var alt := ""
	for t in STAT_TOKENS:
		alt += t if alt == "" else "|" + t
	return alt

## Every editable value in the formula, left-to-right: numeric literals (e.g. a
## flat "5") AND stat names. These are what the Workshop lets you swap to a stat.
## Operators, parentheses and utility tokens (block, enemies, here, noise, burn)
## are skipped — they aren't stats and can't be retuned.
func value_tokens() -> Array:
	var result : Array = []
	var regex := RegEx.new()
	regex.compile("(\\d+\\.?\\d*|" + _stat_alternation() + ")")
	for m in regex.search_all(formula):
		result.append(FormulaToken.new(m.get_string(1), m.get_start(), m.get_end()))
	return result

## Swap the value at `token_index` for `target` (e.g. "heat"), rewriting the
## formula and forcing a recompile so the next calculate() reflects it.
func retune_token(token_index: int, target: String) -> void:
	var tokens := value_tokens()
	if token_index < 0 or token_index >= tokens.size():
		push_warning("retune_token: index %d out of range (%d tokens)" % [token_index, tokens.size()])
		return
	var tok : FormulaToken = tokens[token_index]
	formula = formula.substr(0, tok.start) + target + formula.substr(tok.end)
	_compiled = false
	_expression = null
