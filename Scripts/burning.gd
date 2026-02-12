extends Condition
class_name Burning

var decrement := 1

# This method is called by the entity when it receives the apply_condition signal
func apply_condition(who, condition: Condition):
	entity = who
	
	# Check if entity already has this type of condition
	var existing_burning = _get_existing_burning(who)
	
	if existing_burning == null:
		# Entity doesn't have burning yet, add new instance
		var new_burning = condition.duplicate(true)
		new_burning.entity = who
		new_burning.stacks = condition.stacks
		who.conditions.append(new_burning)  # FIXED: Changed from condition to conditions
		
		# Connect to time_passed signal for this new instance
		Global.time_passed.connect(new_burning.trigger_condition)
	else:
		# Entity already has burning, add stacks
		existing_burning.stacks += condition.stacks

func _get_existing_burning(who) -> Burning:
	for each_condition in who.conditions:  # FIXED: Changed from condition to conditions
		if each_condition is Burning:
			return each_condition
	return null

func trigger_condition():
	if entity:
		entity.take_damgage(stacks)
		stacks -= decrement
