extends CanvasLayer
class_name UIBar

var run_manager : RunManager
@onready var hp_label = $"UI Bar/HBoxContainer/hp label"
@onready var gold_label = $"UI Bar/HBoxContainer/gold label"

func _ready() -> void:
	set_gold()
	set_health()

func set_health():
	if run_manager and run_manager.player:
		var max_hp = run_manager.character.max_health.calculate(run_manager.player)
		hp_label.text = str(run_manager.character.current_health) + "/" + str(run_manager.character.max_health.calculate(run_manager.player))

func set_gold():
	gold_label.text = str(run_manager.character.gold)


func _on_settings_pressed() -> void:
	pass # get a setting menu


func _on_help_pressed() -> void:
	pass # get a help menu


func _on_log_pressed() -> void:
	pass # get a battle log
