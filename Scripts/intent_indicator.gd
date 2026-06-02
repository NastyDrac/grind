extends Sprite2D
class_name IntentIndicator

var label : Label
@export var enemy : Enemy

var attack_icon = preload("res://Art/Icons/BATTLEIconAlt.png")
var move_icon = preload("res://Art/Icons/ArrowIcon.png")

## Optional icon for non-damaging "attacks" (e.g. the Bugler's bugle). If left
## unassigned, the indicator just shows a music note with no icon.
@export var support_icon : Texture2D

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
			var dmg : int = enemy.get_intent_damage()
			if dmg > 0:
				# A real attack — show the battle icon and the damage number.
				flip_h = false
				texture = attack_icon
				label.text = str(dmg)
			else:
				# A non-damaging action (e.g. the Bugler bugling). Not an attack,
				# so don't show "0" with the battle icon.
				flip_h = false
				texture = support_icon   # null is fine — just the note shows
				label.text = "♪"
		MoveStep.MoveAction.RETREAT:
			flip_h = true
			texture = move_icon
			label.text = str(enemy.data.move_speed)
		MoveStep.MoveAction.HOLD:
			flip_h = false
			texture = move_icon
			label.text = "•"
		_: # ADVANCE or unmatched
			flip_h = false
			texture = move_icon
			label.text = str(enemy.data.move_speed)
