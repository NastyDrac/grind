extends Resource
class_name WinCondition

## Base class for win conditions
## Override check_win_condition() in subclasses to implement specific win logic

# Reference to the run_manager
var run_manager: RunManager

# Called when combat starts - use this to set up tracking
func initialize(manager: RunManager) -> void:
	run_manager = manager
	_setup()

# Override this in subclasses to set up signals, counters, etc.
func _setup() -> void:
	pass

# Override this in subclasses to check if the win condition is met
# Return true if player has won
func check_win_condition() -> bool:
	push_error("check_win_condition() must be implemented in subclass")
	return false

# Get a description of the current progress (for UI display)
# Example: "Enemies Defeated: 5/10"
func get_progress_text() -> String:
	return ""

# Cleanup when combat ends
func cleanup() -> void:
	pass
