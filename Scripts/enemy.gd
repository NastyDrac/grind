extends Node2D
class_name Enemy

var data : EnemyData
var current_health : int
var current_range : int = 5

var range_manager : RangeManager
var target_position : Vector2
var movement_speed : float = 10.0
var selectable : bool = false
var is_targeted : bool = false
var conditions : Array[Condition] = []
var run_manager 

signal enemy_attack_player(enemy : Enemy, damage : int)
signal enemy_moved(enemy : Enemy, old_range : int, new_range : int)

@onready var sprite := $Sprite2D

@onready var selection_highlight = $SelectionHighlight if has_node("SelectionHighlight") else null
@onready var target_highlight = $TargetHighlight if has_node("TargetHighlight") else null
@onready var health_bar = $health_bar

func _ready():
	
	Global.time_passed.connect(_on_enemies_advance)
	Global.apply_condition.connect(_on_apply_condition)  
	
	
	if selection_highlight:
		selection_highlight.visible = false
	if target_highlight:
		target_highlight.visible = false


func _on_apply_condition(target, condition_to_apply: Condition):
	if target != self:
		return
	
	
	condition_to_apply.apply_condition(self, condition_to_apply)

func resize_collision_shape():
	$Sprite2D/Area2D/CollisionShape2D.shape.size = data.texture.get_size()
	health_bar.position.y -= get_visual_height()/2

func set_range_manager(manager : RangeManager):
	range_manager = manager

func set_data(enemy_data: EnemyData, spawn_range : int = 5):
	data = enemy_data
	current_health = data.max_health
	current_range = spawn_range
	sprite.texture = data.texture
	resize_collision_shape()
	set_health_bar()
	if data.conditions and data.conditions.size() > 0:
		for condition in data.conditions:
			condition.apply_condition(self, condition)

func take_damgage(amount : int):
	current_health -= amount
	set_health_bar()
	if current_health <= 0:
		die()

func die():
	Global.enemy_dies.emit(self)
	queue_free()

# 
func _on_enemies_advance():
	move_toward_player()

func move_toward_player():
	if current_range <= data.attack_range:
		attack_player()
		return
	
	
	var old_range = current_range
	current_range = max(1, current_range - data.move_speed)
	
	
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
	
	enemy_moved.emit(self, old_range, current_range)
	


func attack_player():
	Global.enemy_attacks_player.emit(self, data.damage)

func get_current_range() -> int:
	return current_range

func is_alive() -> bool:
	return current_health > 0

func _process(delta: float) -> void:
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
		position = position.lerp(target_position, movement_speed * delta)

func _on_area_2d_mouse_entered() -> void:
	if selectable:
		range_manager.enemy_hovered = self
		_show_hover_feedback()

func _on_area_2d_mouse_exited() -> void:
	if range_manager and range_manager.enemy_hovered == self:
		range_manager.enemy_hovered = null
	_hide_hover_feedback()

func get_visual_height() -> float:
	if has_node("Sprite2D"):
		return $Sprite2D.texture.get_height() * $Sprite2D.scale.y
	return 100.0

func set_health_bar():
	health_bar.max_value = data.max_health
	health_bar.value = current_health
	$health_bar/Label.text = str(current_health)

# ============================================================================
# TARGETING VISUAL FEEDBACK
# ============================================================================

func make_selectable():
	if not selectable:
		selectable = true
		_update_visual_state()

func make_unselectable():
	if selectable:
		selectable = false
		_update_visual_state()

func set_targeted(targeted: bool):
	is_targeted = targeted
	_update_visual_state()

func _update_visual_state():
	
	if selection_highlight:
		selection_highlight.visible = selectable and not is_targeted
	
	
	if target_highlight:
		target_highlight.visible = is_targeted
	
	if not selection_highlight and not target_highlight:
		if is_targeted:
			sprite.modulate = Color(1.0, 1.0, 0.5) 
		elif selectable:
			sprite.modulate = Color(1.0, 1.0, 1.0)  
		else:
			sprite.modulate = Color(0.7, 0.7, 0.7)  

func _show_hover_feedback():
	if not is_targeted:
		if selection_highlight:
			selection_highlight.modulate = Color(1.2, 1.2, 1.2)  
		elif not target_highlight:
			sprite.modulate = Color(1.2, 1.2, 1.2) 

func _hide_hover_feedback():
	if not is_targeted:
		if selection_highlight:
			selection_highlight.modulate = Color(1.0, 1.0, 1.0) 
		elif not target_highlight:
			_update_visual_state()  
