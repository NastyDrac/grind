extends Resource
class_name ValueCalculator

@export_multiline var formula: String = "grit"


var _expression: Expression = null
var _compiled: bool = false

func calculate(player : Character) -> int:
	if not player:
		return 0
	
	return _calculate_formula(player)


func _calculate_formula(player : Character) -> int:
	
	if not _compiled:
		_compile_expression()
	
	if not _expression:
		push_error("Expression failed to compile")
		return 0
	
	
	var swag_stat = _find_stat_from_character(player, Stat.STAT.SWAG)
	var guts_stat = _find_stat_from_character(player, Stat.STAT.GUTS)
	var bang_stat = _find_stat_from_character(player, Stat.STAT.BANG)
	var hustle_stat = _find_stat_from_character(player, Stat.STAT.HUSTLE)
	var marbles_stat = _find_stat_from_character(player, Stat.STAT.MARBLES)
	var mojo_stat = _find_stat_from_character(player, Stat.STAT.MOJO)
	
	
	var result = _expression.execute([swag_stat, guts_stat, bang_stat, hustle_stat, marbles_stat, mojo_stat])
	
	if _expression.has_execute_failed():
		push_error("Expression execution failed: %s" % _expression.get_error_text())
		return 0
	
	return int(result)

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
