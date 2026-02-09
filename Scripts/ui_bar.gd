extends CanvasLayer
class_name UIBar

var run_manager : RunManager
@onready var hp_label = $"UI Bar/HBoxContainer/hp label"
@onready var gold_label = $"UI Bar/HBoxContainer/gold label"

# Track if character sheet is open
var is_character_sheet_open : bool = false

func _ready() -> void:
	set_gold()
	set_health()

func set_health():
	if run_manager and run_manager.player:
		var max_hp = run_manager.character.max_health.calculate(run_manager.player)
		hp_label.text = str(run_manager.character.current_health) + "/" + str(max_hp)

func set_gold():
	gold_label.text = str(run_manager.character.gold)


func _on_settings_pressed() -> void:
	# Release focus to prevent accidental re-triggering
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()
	# get a setting menu


func _on_help_pressed() -> void:
	# Release focus to prevent accidental re-triggering
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()
	# get a help menu


func _on_log_pressed() -> void:
	print("button pressed ")
	# Get the button that was pressed and release its focus
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control and focused_control is BaseButton:
		focused_control.release_focus()
	
	# Toggle character sheet on/off
	if is_character_sheet_open:
		# Close it
		run_manager.close_character_sheet()
		is_character_sheet_open = false
	else:
		# Open it - show appropriate stats based on game state
		if run_manager.current_state == RunManager.GameState.COMBAT and run_manager.player:
			# During combat, show live combat stats
			run_manager.show_combat_character_sheet()
		else:
			# Outside combat, show base stats
			run_manager.show_base_character_sheet()
		is_character_sheet_open = true
