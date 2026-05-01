extends Sprite2D
class_name IntentIndicator

var label : Label
@export var enemy : Enemy

var attack_icon = preload("res://Art/Icons/BATTLEIconAlt.png")
var move_icon = preload("res://Art/Icons/ArrowIcon.png")

func _ready() -> void:
	label = Label.new()
	add_child(label)
	label.add_theme_color_override("font_color", Color.BLACK)
	Global.enemy_advanced.connect(get_intent.bind())
	get_intent(enemy, 0, enemy.current_range)


func get_intent(character : Enemy, old : int, new : int):
	if character != enemy:
		return
	match enemy.get_next_intent():
		MoveStep.MoveAction.ATTACK, MoveStep.MoveAction.ATTACK_THEN_RETREAT, MoveStep.MoveAction.ATTACK_THEN_ADVANCE:
			texture = attack_icon
			label.text = str(enemy.get_attack_damage())
		MoveStep.MoveAction.RETREAT:
			texture = move_icon
			label.text = "←"
		MoveStep.MoveAction.HOLD:
			texture = move_icon
			label.text = "•"
		_: # ADVANCE or unmatched
			texture = move_icon
			label.text = str(enemy.data.move_speed)
