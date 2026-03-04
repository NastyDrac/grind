@abstract
extends Resource
class_name Condition
@export var condition_name : String
@export var stacks : int = 0

@export var icon: Texture2D

@export var description: String = ""

## When true, the condition icon will display the current stacks value as a number.
@export var show_stacks: bool = false

var entity 

func apply_condition(who, condition : Condition) -> void:
	pass
func trigger_condition() -> void:
	pass


func enemy_has_condition_type(who: Enemy, condition_type) -> bool:
	for each_condition in who.conditions:        # was who.condition
		if each_condition.get_script() == condition_type.get_script():
			return true
	return false

func get_existing_condition(who, condition_type) -> Condition:
	for each_condition in who.conditions:        # was who.condition
		if each_condition.get_script() == condition_type.get_script():
			return each_condition
	return null


func get_condition_name() -> String:
	if condition_name:
		return condition_name
		
	var script = get_script()
	if script:
		var this_class = script.get_global_name()
		if this_class:
			return this_class
	return "Condition"
