extends WinCondition
class_name SurviveXTurns

## Win by surviving X turns (time passes)
## Enemies spawn when player plays cards (via card_cost system)
## This win condition only tracks turns - it doesn't spawn enemies

@export var turns_to_survive: int = 10

var turns_survived: int = 0

func _setup() -> void:
	# Connect to time_passed signal
	Global.time_passed.connect(_on_time_passed)

func _on_time_passed() -> void:
	turns_survived += 1
	
	# Check if we've survived long enough
	if check_win_condition():
		run_manager.on_combat_won()

func check_win_condition() -> bool:
	return turns_survived >= turns_to_survive

func get_progress_text() -> String:
	return "Turns Survived: %d/%d" % [turns_survived, turns_to_survive]

func cleanup() -> void:
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
