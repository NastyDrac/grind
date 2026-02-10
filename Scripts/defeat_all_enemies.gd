extends WinCondition
class_name DefeatAllEnemies

## Win by defeating all enemies in a specific list
## No new enemies spawn - you must defeat the predetermined wave

@export var enemy_wave: Array[EnemyData] = []  # Specific enemies to spawn
@export var spawn_range: int = 5

var total_enemies: int = 0
var enemies_defeated: int = 0

func _setup() -> void:
	# Spawn all enemies from the wave
	total_enemies = enemy_wave.size()
	
	if run_manager and run_manager.range_manager:
		for enemy_data in enemy_wave:
			run_manager.range_manager.spawn_enemy(enemy_data, spawn_range)
	
	# Connect to enemy death signal
	Global.enemy_dies.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	enemies_defeated += 1
	
	# Check if all enemies are defeated
	if check_win_condition():
		run_manager.on_combat_won()

func check_win_condition() -> bool:
	# Win when all enemies are defeated
	return enemies_defeated >= total_enemies and total_enemies > 0

func get_progress_text() -> String:
	return "Enemies Remaining: %d/%d" % [total_enemies - enemies_defeated, total_enemies]

func cleanup() -> void:
	if Global.enemy_dies.is_connected(_on_enemy_died):
		Global.enemy_dies.disconnect(_on_enemy_died)
