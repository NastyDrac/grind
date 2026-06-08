extends Condition
class_name Bloated

## Guards the death explosion so it triggers exactly once, even if the damage it
## deals causes further enemy_dies emissions.
var _exploded : bool = false

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
	if dying_enemy != entity:
		return
	if _exploded:
		return
	_exploded = true

	# Disconnect BEFORE dealing any damage so the resulting hit can't re-enter
	# this handler and loop.
	if Global.enemy_dies.is_connected(on_enemy_dies):
		Global.enemy_dies.disconnect(on_enemy_dies)

	if dying_enemy.current_range == 1:
		Global.enemy_attacks_player.emit(dying_enemy, stacks)

func get_description_with_values() -> String:
	return "If at range 1, on death, deal %s damage." % stacks
