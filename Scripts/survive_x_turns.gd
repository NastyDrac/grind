extends WinCondition
class_name SurviveXTurns



@export var turns_to_survive: int = 10

var turns_survived: int = 0

func _setup() -> void:
	
	Global.time_passed.connect(_on_time_passed)

func _on_time_passed() -> void:
	turns_survived += 1
	
	
	if check_win_condition():
		run_manager.on_combat_won()

func check_win_condition() -> bool:
	return turns_survived >= turns_to_survive

func get_progress_text() -> String:
	return "Turns Survived: %d/%d" % [turns_survived, turns_to_survive]

func cleanup() -> void:
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
func get_announcement_text() -> String:
	return "Survive %d Turns" % turns_to_survive
