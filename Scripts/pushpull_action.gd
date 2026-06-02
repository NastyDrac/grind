extends Action
class_name PushPullAction


@export var distance_calculator: ValueCalculator


@export var enemy_count_calculator: ValueCalculator

func get_action_type() -> String:
	return "Push/Pull"

func execute(target: Enemy) -> void:
	if not player:
		push_error("PushPullAction requires valid Character")
		return

	if not target:
		push_error("PushPullAction requires valid Enemy target")
		return

	var distance = _calculate_distance()

	# Enemy.push() owns the range bounds: it clamps to [1, range manager max] so
	# an enemy can never reach range 0 (the player's slot) or exceed the
	# playfield, and it emits enemy_advanced + enemy_player_moved for both
	# directions. Positive distance pushes away; negative pulls toward.
	target.push(distance)

func get_description_with_values(character: Character) -> String:
	if not character or not distance_calculator:
		return "Push/Pull enemy"


	var distance = distance_calculator.calculate(character)


	var formula_display = _format_formula_display(distance_calculator.formula)


	var action_word = "Push" if distance > 0 else "Pull"
	var abs_distance = abs(distance)


	var desc = ""

	match target_type:
		TargetType.SINGLE_ENEMY:
			desc = "%s: §%d§ (%s)" % [action_word, abs_distance, formula_display]

		TargetType.ALL_ENEMIES:
			desc = "%s: §%d§ (%s) all enemies" % [action_word, abs_distance, formula_display]

		TargetType.ALL_ENEMIES_AT_RANGE:
			desc = "%s: §%d§ (%s) all at range" % [action_word, abs_distance, formula_display]

		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				var count_formula = _format_formula_display(enemy_count_calculator.formula)
				desc = "%s: §%d§ (%s) on §%d§ (%s) enemies" % [action_word, abs_distance, formula_display, count, count_formula]
			else:
				desc = "%s: §%d§ (%s) multiple enemies" % [action_word, abs_distance, formula_display]

		TargetType.SELF:
			desc = "%s: Cannot target self" % action_word

	return desc

func _calculate_distance() -> int:
	if distance_calculator and player:
		return distance_calculator.calculate(player)
	return 1


func get_num_targets(character: Character) -> int:
	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE and enemy_count_calculator:
		return enemy_count_calculator.calculate(character)
	return 1
