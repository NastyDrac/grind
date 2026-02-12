extends Condition
class_name ItemDropper

@export var chance: ValueCalculator
@export var item: ItemData

# This method is called by the entity when it receives the apply_condition signal
func apply_condition(who, condition: Condition) -> void:
	entity = who
	
	# Add this condition to the entity's condition array
	# (ItemDropper doesn't stack like Burning, it's just a passive effect)
	var new_dropper = condition.duplicate(true)
	new_dropper.entity = who
	who.conditions.append(new_dropper)  # FIXED: Changed from condition to conditions
	
	# Connect to enemy death signal when condition is applied
	# Use the new instance's callback, not self
	if not Global.enemy_dies.is_connected(new_dropper._on_enemy_death):
		Global.enemy_dies.connect(new_dropper._on_enemy_death)

func drop_item(enemy_range: int, enemy_position: Vector2):
	# Get run_manager dynamically when needed instead of storing it
	var run_manager = entity.run_manager
	
	if not run_manager:
		return
		
	if not run_manager.range_manager:
		return
	
	run_manager.range_manager.spawn_item(item, enemy_range, enemy_position)

func _on_enemy_death(enemy: Enemy):
	if not entity:
		return
	
	# Only trigger if the enemy that died is the one this condition is attached to
	if enemy != entity:
		return
	
	# Get run_manager when needed (it might be set by now)
	var run_manager = entity.run_manager
	
	if not run_manager:
		return
	
	var drop_chance = chance.calculate(entity)
	var roll = run_manager.rng.randi_range(0, 99)
	
	if roll < drop_chance:
		drop_item(enemy.get_current_range(), enemy.global_position)
