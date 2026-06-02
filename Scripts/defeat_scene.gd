extends Control
## Defeat screen. A dumb view: it only announces that the player pressed the
## button. RunManager wires `restart_requested` to end the run. The root is a
## full-rect Control with a CenterContainer, so it centers itself regardless of
## what it's parented to.

signal restart_requested

## Set automatically by RunManager when the screen is shown.
var run_manager : RunManager = null

@onready var _button : Button = $PanelContainer/VBoxContainer/HBoxContainer/Button

func _ready() -> void:
	_button.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed() -> void:
	restart_requested.emit()
