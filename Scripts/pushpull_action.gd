extends Action
class_name PushPullAction

# Amount to push/pull (positive = push away, negative = pull closer)
@export var distance_calculator: ValueCalculator

# Number of enemies to affect (only used for X_ENEMIES_UP_TO_RANGE)
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
	
	# Calculate the distance to push/pull
	var distance = _calculate_distance()
	
	# Get current range of enemy
	var current_range = target.get_current_range()
	var old_range = current_range
	
	# Calculate new range (positive distance = push away, negative = pull closer)
	# Max range is typically 5, min is 0 (at player)
	var new_range = clamp(current_range + distance, 0, 5)
	
	# If range actually changed, emit the movement signal
	if new_range != old_range:
		target.current_range = new_range
		target.enemy_moved.emit(target, old_range, new_range)

func get_description_with_values(character: Character) -> String:
	if not character or not distance_calculator:
		return "Push/Pull enemy"
	
	# Calculate distance
	var distance = distance_calculator.calculate(character)
	
	# Format the formula with stat names
	var formula_display = _format_formula_display(distance_calculator.formula)
	
	# Determine if it's a push or pull
	var action_word = "Push" if distance > 0 else "Pull"
	var abs_distance = abs(distance)
	
	# Build description based on targeting
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

# Override from Action base class
func get_num_targets(character: Character) -> int:
	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE and enemy_count_calculator:
		return enemy_count_calculator.calculate(character)
	return 1
