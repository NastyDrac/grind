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

func get_progress_fraction() -> float:
	if enemies_to_defeat <= 0:
		return 0.0
	return clampf(float(enemies_defeated) / float(enemies_to_defeat), 0.0, 1.0)

func cleanup() -> void:
	if Global.enemy_dies.is_connected(_on_enemy_died):
		Global.enemy_dies.disconnect(_on_enemy_died)
func get_announcement_text() -> String:
	return "Defeat %d Enemies" % enemies_to_defeat
