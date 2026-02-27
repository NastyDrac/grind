extends Action
class_name ModifyStatAction

@export var temp_modify : bool = true
@export var modify_calculator : ValueCalculator
@export var stat_to_modify : Stat.STAT

func get_action_type() -> String:
	return "Modify"

func execute(target: Variant) -> void:
	if not player:
		push_error("ModifyStatAction requires valid player")
		return
	if temp_modify:
		for stat : Stat in player.stats:
			if stat.stat_type == stat_to_modify:
				stat.modify_stat(modify_calculator.calculate(player))
	if !temp_modify:
		for stat : Stat in player.character_data.stats:
			if stat.stat_type == stat_to_modify:
				stat.modify_stat(modify_calculator.calculate(player))

func get_description_with_values(character: Variant) -> String:
	if not character or not modify_calculator:
		return "Modify"

	var mod_value      : int    = modify_calculator.calculate(character)
	var formula        : String = modify_calculator.formula
	var stat_name      : String = _get_stat_name(stat_to_modify)
	var modifier_sign  : String = "+" if mod_value >= 0 else ""
	var is_plain_number: bool   = formula.is_valid_int()

	if is_plain_number:
		# e.g. "Modify Swag: +§5§"  — no formula needed
		return "Modify %s: %s%d" % [stat_name, modifier_sign, mod_value]
	else:
		# e.g. "Modify Swag: +§10§ (swag * 2)"
		var formula_display := _format_formula_display(formula)
		return "Modify %s: §%s%d§ (%s)" % [stat_name, modifier_sign, mod_value, formula_display]
func _get_stat_name(stat_type: Stat.STAT) -> String:
	match stat_type:
		Stat.STAT.SWAG:
			return "Swag"
		Stat.STAT.MARBLES:
			return "Marbles"
		Stat.STAT.GUTS:
			return "Guts"
		Stat.STAT.BANG:
			return "Bang"
		Stat.STAT.HUSTLE:
			return "Hustle"
		Stat.STAT.MOJO:
			return "Mojo"
		_:
			return "Unknown"
