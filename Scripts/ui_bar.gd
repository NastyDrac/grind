extends CanvasLayer
class_name UIBar

var run_manager : RunManager
@onready var hp_label = $"UI Bar/HBoxContainer/hp label"
@onready var gold_label = $"UI Bar/HBoxContainer/gold label"


var is_character_sheet_open : bool = false

func set_health():
	if run_manager and run_manager.player:
		var max_hp = run_manager.character.max_health.calculate(run_manager.player)
		hp_label.text = str(run_manager.character.current_health) + "/" + str(max_hp)

func set_gold():
	gold_label.text = str(run_manager.character.gold)


func _on_settings_pressed() -> void:
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()



func _on_help_pressed() -> void:
	
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()
	


func _on_log_pressed() -> void:
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()
	
	
	if is_character_sheet_open:
		
		run_manager.close_character_sheet()
		is_character_sheet_open = false
	else:
		
		if run_manager.current_state == RunManager.GameState.COMBAT and run_manager.player:
			
			run_manager.show_combat_character_sheet()
		else:
			
			run_manager.show_base_character_sheet()
		is_character_sheet_open = true
