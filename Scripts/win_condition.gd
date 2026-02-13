extends Resource
class_name WinCondition

var run_manager: RunManager

func initialize(manager: RunManager) -> void:
	run_manager = manager
	_setup()
	
func _setup() -> void:
	pass
	
func check_win_condition() -> bool:
	push_error("check_win_condition() must be implemented in subclass")
	return false


func get_progress_text() -> String:
	return ""


func cleanup() -> void:
	pass
