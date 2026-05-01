@abstract
extends Resource
class_name Condition
@export var condition_name : String
@export var stacks : int = 0

@export var icon: Texture2D

@export var description: String

## When true, the condition icon will display the current stacks value as a number.
@export var show_stacks: bool = false

var entity 

func apply_condition(who, condition : Condition) -> void:
	entity = who
	who.conditions.append(self.duplicate())
func trigger_condition() -> void:
	pass

## Called when the condition is being cleaned up (e.g. end of wave).
## Override to disconnect signals or release references.
## NOTE: do NOT erase self from who.conditions here — the caller manages the array.
func remove_condition(who) -> void:
	who.conditions.erase(self)

## Returns the description string shown in tooltips and the shop.
## Override in subclasses to include dynamic values (e.g. calculated damage).
## Falls back to the exported description field if not overridden.
func get_description_with_values() -> String:
	return "Description must be set in condition"


func enemy_has_condition_type(who: Enemy, condition_type) -> bool:
	for each_condition in who.conditions:
		if each_condition.get_script() == condition_type.get_script():
			return true
	return false

func get_existing_condition(who, condition_type) -> Condition:
	for each_condition in who.conditions:
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
