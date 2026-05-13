extends Resource
class_name ValueCalculator

@export_multiline var formula: String = "swag"


var _expression: Expression = null
var _compiled: bool = false

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
	regex.compile("(\\d*\\.\\d+)\\s*\\*\\s*(swag|guts|bang|hustle|marbles|mojo)")
	var match_result = regex.search(display)
	while match_result:
		var pct = int(round(float(match_result.get_string(1)) * 100.0))
		var stat = match_result.get_string(2)
		display = (display.substr(0, match_result.get_start())
				+ str(pct) + "% " + stat
				+ display.substr(match_result.get_end()))
		match_result = regex.search(display)

	# Pattern: stat_name * 0.XX  (stat first)
	regex.compile("(swag|guts|bang|hustle|marbles|mojo)\\s*\\*\\s*(\\d*\\.\\d+)")
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
	
	if not _expression:
		push_error("Expression failed to compile")
		return 0
	
	# Cast stats to float so division produces correct results.
	# Without this, GDScript integer division truncates: e.g. 3/5 = 0 instead of 0.6.
	var swag_stat    = float(_find_stat_from_character(player, Stat.STAT.SWAG))
	var guts_stat    = float(_find_stat_from_character(player, Stat.STAT.GUTS))
	var bang_stat    = float(_find_stat_from_character(player, Stat.STAT.BANG))
	var hustle_stat  = float(_find_stat_from_character(player, Stat.STAT.HUSTLE))
	var marbles_stat = float(_find_stat_from_character(player, Stat.STAT.MARBLES))
	var mojo_stat    = float(_find_stat_from_character(player, Stat.STAT.MOJO))
	
	var result = _expression.execute([swag_stat, guts_stat, bang_stat, hustle_stat, marbles_stat, mojo_stat])
	
	if _expression.has_execute_failed():
		push_error("Expression execution failed: %s" % _expression.get_error_text())
		return 0
	
	return int(round(result))

func _find_stat_from_character(player: Character, stat_type: Stat.STAT) -> int:
	for stat in player.stats:
		if stat.stat_type == stat_type:
			return stat.value
	return 0

func _compile_expression() -> void:
	_expression = Expression.new()
	# Parse with variable names as input
	var error = _expression.parse(formula, ["swag", "guts", "bang", "hustle", "marbles", "mojo"])
	
	if error != OK:
		push_error("Failed to parse formula '%s': %s" % [formula, _expression.get_error_text()])
		_expression = null
	
	_compiled = true
