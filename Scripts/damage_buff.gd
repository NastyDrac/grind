extends Condition
class_name DamageBuffCondition

## Damage added to the enemy's attacks per stack.



func apply_condition(who, condition: Condition) -> void:
	entity = who
	var existing := _get_existing_damage_buff(who)
	if existing == null:
		var new_buff : DamageBuffCondition = condition.duplicate(true)
		new_buff.entity = who
		new_buff.stacks = condition.stacks
		who.conditions.append(new_buff)
	else:
		existing.stacks += condition.stacks


func remove_condition(who) -> void:
	pass


func get_description_with_values() -> String:
	return "gain %d damage." % stacks


func _get_existing_damage_buff(who) -> DamageBuffCondition:
	for each_condition in who.conditions:
		if each_condition is DamageBuffCondition:
			return each_condition
	return null

func modify_attack():
	return stacks
