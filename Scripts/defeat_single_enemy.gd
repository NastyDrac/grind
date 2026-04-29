extends WinCondition
class_name DefeatSingleEnemy



var target_enemy: Enemy 

func _setup() -> void:
	Global.enemy_dies.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	if check_win_condition():
		run_manager.on_combat_won()

func check_win_condition() -> bool:
	return target_enemy.current_health <= 0

func get_progress_text() -> String:
	return "Defeat: %s" % target_enemy.data.enemy_name



func cleanup() -> void:
	if Global.enemy_dies.is_connected(_on_enemy_died):
		Global.enemy_dies.disconnect(_on_enemy_died)

func get_announcement_text() -> String:
	return "Defeat %s" % target_enemy.data.enemy_name
