extends Node2D
class_name Item

@export var item: ItemData
var range_manager: RangeManager
var current_range: int = 0
var target_position: Vector2
var movement_speed: float = 10.0

var sprite: Sprite2D

signal item_collected(item: Item)

func _ready():
	
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	else:
		sprite = $Sprite2D
	
	
	if item and item.icon:
		sprite.texture = item.icon
	
	
	Global.time_passed.connect(_on_time_passed)
	
	
	if item and item.auto_pickup:
		
		call_deferred("collect_item")

func set_item(data: ItemData):
	item = data
	if sprite and item.icon:
		sprite.texture = item.icon
	
	
	if item and item.auto_pickup and is_inside_tree():
		call_deferred("collect_item")

func set_range(r: int):
	current_range = r

func get_current_range() -> int:
	return current_range

func _process(delta: float) -> void:
	
	global_position = global_position.lerp(target_position, movement_speed * delta)

func update_target_position():
	"""Recalculate target position from range manager"""
	if range_manager:
		target_position = range_manager.get_position_for_item(self)

func _on_time_passed():
	
	if item and item.auto_pickup:
		return
	
	advance_toward_player()

func advance_toward_player():
	
	var old_range = current_range
	current_range = max(0, current_range - 1)
	
	
	if current_range == 0:
		collect_item()
	else:
		
		if range_manager:
			
			if range_manager.items_by_range.has(old_range):
				range_manager.items_by_range[old_range].erase(self)
			
		
			if not range_manager.items_by_range.has(current_range):
				range_manager.items_by_range[current_range] = []
			
			if not range_manager.items_by_range[current_range].has(self):
				range_manager.items_by_range[current_range].append(self)
			
			
			range_manager._update_item_positions(old_range)
			range_manager._update_item_positions(current_range)
			
			
			update_target_position()

func collect_item():
	
	# Remove from range manager and scene
	if range_manager:
		range_manager.remove_item(self)
	
	# Emit signal
	Global.item_picked_up.emit(self)
	
	# Remove from scene
	queue_free()
