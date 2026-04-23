extends Action
class_name AttackAction

# Damage calculation
@export var damage_calculator: ValueCalculator

# Number of enemies to hit (only used for X_ENEMIES_UP_TO_RANGE)
@export var enemy_count_calculator: ValueCalculator


func get_action_type() -> String:
	return "Attack"


## Damage is applied AFTER the animation completes.
## The card handler should call play_animation_and_execute() rather than
## execute() directly so the visual stays in sync with the damage.
func execute(target) -> void:
	if not player:
		push_error("AttackAction requires a valid Character")
		return
	if not target:
		push_error("AttackAction.execute: target is null")
		return

	var damage = damage_calculator.calculate(player)
	target.take_damgage(damage)
	Global.player_attacks.emit(player, target, damage)


# ============================================================================
# DESCRIPTION
# ============================================================================

func get_description_with_values(character: Character) -> String:
	if not character:
		return ""
	if not damage_calculator:
		return ""

	var damage = damage_calculator.calculate(character)
	var damage_formula = damage_calculator.formula
	var show_damage_formula = not damage_formula.is_valid_int()

	var desc = ""

	match target_type:
		TargetType.SINGLE_ENEMY:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s)" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage" % damage

		TargetType.ALL_ENEMIES:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to all enemies" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to all enemies" % damage

		TargetType.ALL_ENEMIES_AT_RANGE:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to all at range" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to all at range" % damage

		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				var count_formula = enemy_count_calculator.formula
				var show_count_formula = not count_formula.is_valid_int()

				if show_damage_formula and show_count_formula:
					desc = "Deal §%d§ damage (%s) to §%d§ enemies (%s)" % [damage, _format_formula_display(damage_formula), count, _format_formula_display(count_formula)]
				elif show_damage_formula:
					desc = "Deal §%d§ damage (%s) to §%d§ enemies" % [damage, _format_formula_display(damage_formula), count]
				elif show_count_formula:
					desc = "Deal §%d§ damage to §%d§ enemies (%s)" % [damage, count, _format_formula_display(count_formula)]
				else:
					desc = "Deal §%d§ damage to §%d§ enemies" % [damage, count]
			else:
				if show_damage_formula:
					desc = "Deal §%d§ damage (%s) to multiple enemies" % [damage, _format_formula_display(damage_formula)]
				else:
					desc = "Deal §%d§ damage to multiple enemies" % damage

		TargetType.SELF:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to self" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to self" % damage

	if max_range > 0:
		desc += " - Range: §%d§" % max_range

	return desc


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _calculate_damage() -> int:
	if damage_calculator and player:
		return damage_calculator.calculate(player)
	return 0


func _calculate_damage_from_character(character: Character) -> int:
	if damage_calculator and character:
		return damage_calculator.calculate(character)
	return 0


func _calculate_enemy_count() -> int:
	if enemy_count_calculator and player:
		return enemy_count_calculator.calculate(player)
	return 1


func _calculate_enemy_count_from_character(character: Character) -> int:
	if enemy_count_calculator and character:
		return enemy_count_calculator.calculate(character)
	return 1


func get_enemy_count(character: Character) -> int:
	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE:
		return _calculate_enemy_count_from_character(character)
	return 1


func get_max_range() -> int:
	return max_range


func get_num_targets(character: Character) -> int:
	return _calculate_enemy_count_from_character(character)
