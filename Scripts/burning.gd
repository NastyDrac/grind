extends Condition
class_name Burning

var decrement := 1

func apply_condition(who, condition: Condition):
	entity = who
	

	var existing_burning = _get_existing_burning(who)
	
	if existing_burning == null:
		var new_burning = condition.duplicate(true)
		new_burning.entity = who
		new_burning.stacks = condition.stacks
		who.conditions.append(new_burning)  
		
		Global.time_passed.connect(new_burning.trigger_condition)
	else:
		existing_burning.stacks += condition.stacks

func _get_existing_burning(who) -> Burning:
	for each_condition in who.conditions:  
		if each_condition is Burning:
			return each_condition
	return null

func trigger_condition():
	if entity:
		entity.take_damgage(stacks)
		stacks -= decrement
