extends Condition
class_name ItemDropper

@export var chance: ValueCalculator
@export var item: ItemData


func apply_condition(who, condition: Condition) -> void:
	entity = who
	

	var new_dropper = condition.duplicate(true)
	new_dropper.entity = who
	who.conditions.append(new_dropper)  
	
	
	if not Global.enemy_dies.is_connected(new_dropper._on_enemy_death):
		Global.enemy_dies.connect(new_dropper._on_enemy_death)

func drop_item(enemy_range: int, enemy_position: Vector2):

	var run_manager = entity.run_manager
	
	if not run_manager:
		return
		
	if not run_manager.range_manager:
		return
	
	run_manager.range_manager.spawn_item(item, enemy_range, enemy_position)

func _on_enemy_death(enemy: Enemy):
	if not entity:
		return
	
	
	if enemy != entity:
		return
	

	var run_manager = entity.run_manager
	
	if not run_manager:
		return
	
	var drop_chance = chance.calculate(entity)
	var roll = run_manager.rng.randi_range(0, 99)
	
	if roll < drop_chance:
		drop_item(enemy.get_current_range(), enemy.global_position)
