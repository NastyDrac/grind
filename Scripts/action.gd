@abstract
extends Resource
class_name Action

var player : Character

# Targeting options
enum TargetType {
	SINGLE_ENEMY,           # Target one enemy (at any range player chooses)
	ALL_ENEMIES,            # Target all enemies regardless of range
	ALL_ENEMIES_AT_RANGE,   # Target all enemies at a specific range
	X_ENEMIES_UP_TO_RANGE,  # Target X enemies up to max range
	SELF                    # Target the player character
}
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var max_range : int = 0


func requires_player_target() -> bool:
	return target_type in [TargetType.SINGLE_ENEMY, TargetType.X_ENEMIES_UP_TO_RANGE, TargetType.ALL_ENEMIES_AT_RANGE]


func get_num_targets(character: Character) -> int:
	if target_type == TargetType.SINGLE_ENEMY:
		return 1
	
	return 1


func execute(target) -> void:
	push_error("execute() must be implemented in %s" % get_script().resource_path)
	

func get_action_type() -> String:
	return "Action"


func get_description_with_values(character) -> String:
	if not character:
		return ""
	
	return ""


func _get_stat_value(character: Character, stat_type: Stat.STAT) -> int:
	for stat in character.stats:
		if stat.stat_type == stat_type:
			return stat.value
	return 0

# Helper to format formula for display with stat names (not values)
func _format_formula_display(formula: String) -> String:
	var display = formula
	
	display = display.replace("*", " x ")
	display = display.replace("/", " / ")
	display = display.replace("+", " + ")
	display = display.replace("-", " - ")
	return display
