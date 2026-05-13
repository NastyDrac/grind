extends Condition
class_name Fragile

@export var condition_to_remove : Condition

func on_take_damage(amount : int):
	if entity:
		if entity.current_health > 0:
			for each : Condition in entity.conditions:
				if each.condition_name == condition_to_remove.condition_name:
					each.remove_condition(entity)

func get_description_with_values() -> String:
	return "If hit, but not popped, remove %s " % [condition_to_remove.condition_name]
