extends Condition
class_name Bloated

func apply_condition(who, condition: Condition):
	entity = who
	
	# Check if entity already has this type of condition
	var existing_bloated = _get_existing_bloated(who)
	
	if existing_bloated == null:
		# Entity doesn't have bloated yet, add new instance
		var new_bloated = condition.duplicate(true)  # FIXED: Use condition parameter, not self
		new_bloated.entity = who  # FIXED: Changed from enemy to entity for consistency
		new_bloated.stacks = condition.stacks
		who.conditions.append(new_bloated)
		
		# Connect to enemy_dies signal for this new instance
		Global.enemy_dies.connect(new_bloated.on_enemy_dies)
	else:
		# Entity already has bloated, add stacks
		existing_bloated.stacks += condition.stacks

func _get_existing_bloated(who) -> Bloated:  # FIXED: Removed type hint to work with both Enemy and Character
	for each_condition in who.conditions:
		if each_condition is Bloated:
			return each_condition
	return null

func on_enemy_dies(dying_enemy: Enemy):
	# Check if this is the enemy with the bloated condition
	if dying_enemy == entity:
		# Check if the enemy is at range 1
		if dying_enemy.current_range == 1:
			# Deal damage to the player based on stacks
			Global.enemy_attacks_player.emit(dying_enemy, stacks)
		
		# Disconnect the signal since the enemy is dead
		Global.enemy_dies.disconnect(on_enemy_dies)
