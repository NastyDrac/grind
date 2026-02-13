extends WinCondition
class_name DefeatXEnemies

@export var enemies_to_defeat: int = 10

var enemies_defeated: int = 0

func _setup() -> void:
	Global.enemy_dies.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	enemies_defeated += 1
	
	 
	if check_win_condition():
		run_manager.on_combat_won()

func check_win_condition() -> bool:
	return enemies_defeated >= enemies_to_defeat

func get_progress_text() -> String:
	return "Enemies Defeated: %d/%d" % [enemies_defeated, enemies_to_defeat]

func cleanup() -> void:
	if Global.enemy_dies.is_connected(_on_enemy_died):
		Global.enemy_dies.disconnect(_on_enemy_died)
