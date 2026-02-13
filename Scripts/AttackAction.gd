extends Action
class_name AttackAction

# Damage calculation
@export var damage_calculator: ValueCalculator

# Number of enemies to hit (only used for X_ENEMIES_UP_TO_RANGE)
@export var enemy_count_calculator: ValueCalculator

func get_action_type() -> String:
	return "Attack"

func execute(target : Enemy) -> void:
	if not player:
		push_error("AttackAction requires valid Character with CharacterData")
		return
	target.take_damgage(damage_calculator.calculate(player))
	var damage = _calculate_damage()
	
	if target:
		Global.player_attacks.emit(player, target, damage)

func get_description_with_values(character: Character) -> String:
	if not character:
		return ""
	
	if not damage_calculator:
		return ""
	

	var damage = damage_calculator.calculate(character)
	

	var formula_display = _format_formula_display(damage_calculator.formula)
	

	var desc = ""
	
	match target_type:
		TargetType.SINGLE_ENEMY:
			desc = "Attack: §%d§ (%s)" % [damage, formula_display]
		
		TargetType.ALL_ENEMIES:
			desc = "Attack: §%d§ (%s) to all enemies" % [damage, formula_display]
		
		TargetType.ALL_ENEMIES_AT_RANGE:
			desc = "Attack: §%d§ (%s) to all at range" % [damage, formula_display]
		
		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				var count_formula = _format_formula_display(enemy_count_calculator.formula)
				desc = "Attack: §%d§ (%s) to §%d§ (%s) enemies" % [damage, formula_display, count, count_formula]
			else:
				desc = "Attack: §%d§ (%s) to multiple enemies" % [damage, formula_display]
		
		TargetType.SELF:
			desc = "Attack: §%d§ (%s) to self" % [damage, formula_display]
	
	return desc

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
