extends Node
class_name Character

signal stats_changed()

@export var character_data : CharacterData
var stats : Array[Stat]
var health : int = 0
var block : int = 0

@onready var health_bar = $TextureProgressBar
@onready var sprite = $Sprite2D
@onready var block_display = $TextureProgressBar/ColorRect if has_node("TextureProgressBar/ColorRect") else null
@onready var block_label = $TextureProgressBar/ColorRect/Label if has_node("TextureProgressBar/ColorRect/Label") else null
var run_manager : RunManager

func _ready() -> void:
	Global.item_picked_up.connect(collect_item.bind())
func position_character():
	# Get the range manager to use its positioning logic
	sprite.texture = character_data.character_image
	var range_mgr = get_tree().get_first_node_in_group("range_manager")
	if range_mgr:
		# Get the position for range 0 from the range manager
		var range_0_x = range_mgr._get_x_for_range(0)
		var viewport_size = get_viewport().size
		var center_y = viewport_size.y * range_mgr.center_ratio
		
		# Offset position so sprite is fully visible (not cut off at left edge)
		var sprite_half_width = 0.0
		if sprite.texture:
			sprite_half_width = (sprite.texture.get_size().x * sprite.scale.x) / 2
		
		var range_0_position = Vector2(range_0_x + sprite_half_width + 20, center_y)
		
		# Position sprite at range 0
		sprite.global_position = range_0_position
		
		# Position health bar centered below sprite
		if sprite.texture:
			var sprite_half_height = (sprite.texture.get_size().y * sprite.scale.y) / 2
			var health_bar_width = health_bar.size.x
			
			# Center the health bar horizontally and position it below the sprite
			health_bar.global_position = range_0_position + Vector2(-health_bar_width / 2, sprite_half_height + 10)
		else:
			health_bar.global_position = range_0_position + Vector2(-64, 50)
	else:
		# Fallback if range_manager not found
		var center_y = get_viewport().size.y / 3
		var left_x = 100  # Default left side position
		sprite.global_position = Vector2(left_x, center_y)
		
		var health_bar_width = health_bar.size.x
		health_bar.global_position = Vector2(left_x - health_bar_width / 2, center_y + 100)
	
func take_hit(who : Enemy, damage : int):
	for con : Condition in character_data.special_effects:
		if con.has_method("modify_damage"):
			damage = con.modify_damage(damage)
		else:
			pass
	# Apply block first
	if block > 0:
		var absorbed = min(block, damage)
		block -= absorbed
		damage -= absorbed

	
	# Apply remaining damage to health
	if damage > 0:
		health -= damage
		character_data.current_health = health
	# Ensure block doesn't go negative
	if block < 0:
		block = 0
	
	# Update displays
	display_block()
	set_health_bar()
	if run_manager and run_manager.ui_bar:
		run_manager.ui_bar.set_health()
	
	# Check if dead
	if health <= 0:
		die()

func set_health_bar():
	if health_bar:
		health_bar.max_value = character_data.max_health.calculate(self)
		health_bar.value = max(0, health)

func gain_block(amount : int):
	block += amount
	display_block()

func display_block():
	if block_display and block_label:
		if block > 0:
			block_display.visible = true
			block_label.text = str(block)
		else:
			block_display.visible = false

func die():
	print("Player has died!")
	# Add death handling here
	
func set_data(data : CharacterData):
	character_data = data
	
	for each in character_data.stats:
		stats.append(each)
		each.character = self
	
	for stat in stats:
		stat.get_value()

	for stat in stats:
		stat.stat_modified.connect(_on_stat_modified)
	
	Global.enemy_attacks_player.connect(take_hit.bind())
	
	if character_data.current_health <= 0:
		character_data.current_health = character_data.max_health.calculate(self)
	health = character_data.current_health
	block = 0
	
	# Position sprite and health bar at range 0 (center of screen)
	position_character()
	
	# Apply special effects condition if it exists
	# This happens AFTER position_character and run_manager should be set by now
	if character_data.special_effects and character_data.special_effects.size() > 0:
		for condition in character_data.special_effects:
			condition.apply_condition(self, condition)
	
	# Initialize displays
	set_health_bar()
	display_block()

func _on_stat_modified(stat_type: Stat.STAT, new_value: int):
	stats_changed.emit()

func collect_item(item : Item):
	if item.item.item_name == "Gold":
		var amount = run_manager.rng.randi_range(item.item.min_amount, item.item.max_amount)
		character_data.gold += amount
		run_manager.ui_bar.set_gold()
