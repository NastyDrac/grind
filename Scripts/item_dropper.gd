extends Condition
class_name ItemDropper

@export var chance : ValueCalculator
@export var item : ItemData

var player : Character

func apply_condition(who, condition : Condition) -> void:
	
	if who is Character:
		player = who
		
		# Connect to enemy death signal when condition is applied
		if Global.enemy_dies.is_connected(_on_enemy_death):
			return
		Global.enemy_dies.connect(_on_enemy_death)


func drop_item(enemy_range: int, enemy_position: Vector2):
	
	# Get run_manager dynamically when needed instead of storing it
	var run_manager = player.run_manager if player else null
	
	if not run_manager:
		return
		
	if not run_manager.range_manager:
		return
	
	run_manager.range_manager.spawn_item(item, enemy_range, enemy_position)

func _on_enemy_death(enemy: Enemy):

	if not player:
		return
	
	# Get run_manager when needed (it might be set by now)
	var run_manager = player.run_manager
	
	if not run_manager:
		return
	
	var drop_chance = chance.calculate(player)
	var roll = run_manager.rng.randi_range(0, 99)
	

	
	if roll < drop_chance:
		drop_item(enemy.get_current_range(), enemy.global_position)
