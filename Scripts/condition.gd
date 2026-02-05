@abstract
extends Resource
class_name Condition

@export var stacks : int = 0

# Optional: Icon or texture for UI display
@export var icon: Texture2D

# Optional: Description for tooltip/UI
@export var description: String = ""

# Reference to the enemy this condition is attached to
var enemy : Enemy

# Apply this condition to an enemy or character
# Override this in subclasses to implement specific condition logic
# 'who' can be Enemy, Character, or any other type
func apply_condition(who, condition : Condition) -> void:
	push_error("apply_condition() must be implemented in subclass")

# Trigger the condition effect (called on time_passed or other events)
# Override this in subclasses
func trigger_condition() -> void:
	pass

# Helper method to check if enemy already has this type of condition
func enemy_has_condition_type(who: Enemy, condition_type) -> bool:
	for each_condition in who.condition:
		if each_condition.get_script() == condition_type.get_script():
			return true
	return false

# Helper method to get existing condition of this type from enemy
func get_existing_condition(who: Enemy, condition_type) -> Condition:
	for each_condition in who.condition:
		if each_condition.get_script() == condition_type.get_script():
			return each_condition
	return null

# Get the display name of this condition
func get_condition_name() -> String:
	var script = get_script()
	if script:
		var this_class = script.get_global_name()
		if this_class:
			return this_class
	return "Condition"
