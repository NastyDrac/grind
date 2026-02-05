extends Condition
class_name Burning

var decrement := 1
func apply_condition(who : Enemy, condition : Condition):
	enemy = who
	
	# Check if enemy already has this type of condition
	var existing_burning = _get_existing_burning(who)
	
	if existing_burning == null:
		# Enemy doesn't have burning yet, add new instance
		var new_burning = self.duplicate(true)
		new_burning.enemy = who
		new_burning.stacks = condition.stacks
		who.condition.append(new_burning)
		
		# Connect to time_passed signal for this new instance
		Global.time_passed.connect(new_burning.trigger_condition)
	else:
		# Enemy already has burning, add stacks
		existing_burning.stacks += condition.stacks
	
func _get_existing_burning(who: Enemy) -> Burning:
	for each_condition in who.condition:
		if each_condition is Burning:
			return each_condition
	return null

func trigger_condition():
	if enemy:
		enemy.take_damgage(stacks)
		stacks -= decrement
