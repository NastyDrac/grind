extends Condition
class_name Bloated

func apply_condition(who, condition: Condition):
	entity = who
	
	var existing_bloated = _get_existing_bloated(who)
	
	if existing_bloated == null:
		
		var new_bloated = condition.duplicate(true) 
		new_bloated.entity = who  
		new_bloated.stacks = condition.stacks
		who.conditions.append(new_bloated)
		

		Global.enemy_dies.connect(new_bloated.on_enemy_dies)
	else:
		existing_bloated.stacks += condition.stacks

func _get_existing_bloated(who) -> Bloated:  # FIXED: Removed type hint to work with both Enemy and Character
	for each_condition in who.conditions:
		if each_condition is Bloated:
			return each_condition
	return null

func on_enemy_dies(dying_enemy: Enemy):
	if dying_enemy == entity:

		if dying_enemy.current_range == 1:
			Global.enemy_attacks_player.emit(dying_enemy, stacks)
		
		Global.enemy_dies.disconnect(on_enemy_dies)
