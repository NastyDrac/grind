extends Node2D
class_name Turret

## The range column this turret guards.
var assigned_range: int = 0

## Damage dealt per shot per turret stack.
var damage: ValueCalculator

## How many turrets are stacked here.
var stack_count: int = 1

## Set by DeployTurretAction after spawning.
var run_manager: RunManager

## Optional sprite texture.
var texture: Texture2D = preload("res://Art/turret.png")

var _sprite: Sprite2D
var _stack_label: Label


# ─────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	z_index = 10
	_setup_visual()
	_setup_stack_label()
	Global.time_passed.connect(_on_time_passed)


func _exit_tree() -> void:
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)


# ─────────────────────────────────────────────
# VISUAL SETUP
# ─────────────────────────────────────────────

func _setup_visual() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	if texture:
		_sprite.texture = texture
	else:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(40, 40)
		_sprite.texture = placeholder
		_sprite.modulate = Color(0.3, 0.8, 1.0)


func _setup_stack_label() -> void:
	_stack_label = Label.new()
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack_label.add_theme_font_size_override("font_size", 14)
	_stack_label.add_theme_color_override("font_color", Color.WHITE)
	_stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_stack_label.add_theme_constant_override("shadow_offset_x", 1)
	_stack_label.add_theme_constant_override("shadow_offset_y", 1)
	_stack_label.position = Vector2(-20, 24)
	_stack_label.size = Vector2(40, 20)
	add_child(_stack_label)
	_update_stack_label()


func _update_stack_label() -> void:
	if not _stack_label:
		return
	if stack_count > 1:
		_stack_label.text = "x%d" % stack_count
		_stack_label.visible = true
	else:
		_stack_label.visible = false


# ─────────────────────────────────────────────
# STACKING
# ─────────────────────────────────────────────

func add_stack() -> void:
	stack_count += 1
	_update_stack_label()


# ─────────────────────────────────────────────
# FIRE ON TIME STEP
# ─────────────────────────────────────────────

func _on_time_passed() -> void:
	if not run_manager or not run_manager.range_manager:
		return

	# Each stacked turret fires independently.
	for i in stack_count:
		# Re-fetch and duplicate each shot — a previous shot may have killed
		# an enemy and mutated the range_manager's internal array.
		var enemies: Array = run_manager.range_manager.get_enemies_at_range(assigned_range).duplicate()
		if enemies.is_empty():
			break
		var target: Enemy = enemies.pick_random()
		if target:
			target.take_damgage(damage.calculate(run_manager.player))
