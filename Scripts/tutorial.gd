extends Node2D

@onready var player := $AnimationPlayer
@onready var got_it_button := $"Got it button"

var animations := ["tutorial1", "tutorial2"]
var index := -1

func _ready() -> void:
	position = get_viewport_rect().size / 2.0
	got_it_button.visible = true

func _on_got_it_button_pressed() -> void:
	_next()

func _next() -> void:
	got_it_button.visible = false
	index += 1
	if index >= animations.size():
		queue_free()  # tutorial done — or hide()
		return
	player.play(animations[index])


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	got_it_button.visible = true
