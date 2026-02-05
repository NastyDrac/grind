extends Node2D
class_name RangeManager
@export var spread_multiplier : float = 1
@export var range_spacing: float = 200.0
@export var y_spread_min: float = -300.0
@export var y_spread_max: float = 300.0
@export var enemy_scene: PackedScene = preload("res://Scenes/enemy.tscn")
@export var screen_buffer_y : float = 50.0
@export var wobble_speed := 1.0
@export var wobble_amplitude := 5.0
# Enemy pool for random spawning
@export var enemy_pool: Array[EnemyData] = []
@export var tiered_enemy_pools: Dictionary = {}  # tier (int) -> Array[EnemyData]
@export var center_ratio := .33
# Spawn mode configuration
enum SpawnMode {
	IMMEDIATE,      # Spawn enemies instantly when card is played
	ENERGY_BANKED,  # Bank energy, spawn when drawing
	TIERED          # Higher cost = higher tier enemies
}
@export var spawn_mode: SpawnMode = SpawnMode.IMMEDIATE

var banked_energy: int = 0
var enemies_by_range: Dictionary = {}
var items_by_range : Dictionary = {}
var run_manager : RunManager
# Targeting system
var enemy_hovered : Enemy
var targeting : bool = false
var targets : Array[Enemy] = []
var number_of_targets : int = 0
var current_target_type : Action.TargetType
var current_max_range : int = 0

# Signals for targeting
signal targeting_started()
signal targeting_cancelled()
signal targets_confirmed(targets: Array[Enemy])

func _initialize_ranges(max_range: int):
	for i in range(max_range + 1):
		enemies_by_range[i] = []
		items_by_range[i] = []

# Main entry point for card costs
func process_card_cost(cost: int):
	match spawn_mode:
		SpawnMode.IMMEDIATE:
			_spawn_immediate(cost)
		SpawnMode.ENERGY_BANKED:
			_bank_energy(cost)
		SpawnMode.TIERED:
			_spawn_tiered(cost)

func _ready() -> void:
	add_to_group("range_manager")
	_initialize_ranges(5)
	
	# Connect to global enemy death signal
	Global.enemy_dies.connect(_on_enemy_died)

# Called when player draws a card (only relevant for ENERGY_BANKED mode)
func process_card_draw():
	if spawn_mode == SpawnMode.ENERGY_BANKED and banked_energy > 0:
		_spawn_immediate(banked_energy)
		banked_energy = 0

# Mode 1: Spawn N random enemies immediately
func _spawn_immediate(count: int):
	if enemy_pool.is_empty():
		push_warning("Enemy pool is empty!")
		return
	
	for i in count:
		var random_enemy = enemy_pool.pick_random()
		spawn_enemy(random_enemy, 5)

# Mode 2: Bank energy for later
func _bank_energy(amount: int):
	banked_energy += amount

# Mode 3: Spawn enemies from tier-appropriate pool
func _spawn_tiered(tier: int):
	if not tiered_enemy_pools.has(tier):
		push_warning("No enemies defined for tier %d" % tier)
		return
	
	var tier_pool = tiered_enemy_pools[tier]
	if tier_pool.is_empty():
		push_warning("Tier %d enemy pool is empty!" % tier)
		return
	
	var random_enemy = tier_pool.pick_random()
	spawn_enemy(random_enemy, 5)

func spawn_enemy(enemy_data: EnemyData, spawn_range: int = 5) -> Enemy:
	if not enemy_scene:
		push_error("Enemy scene not assigned to RangeManager!")
		return null
	
	var enemy: Enemy = enemy_scene.instantiate()
	
	add_child(enemy)
	enemy.set_data(enemy_data, spawn_range)
	
	enemy.set_range_manager(self)
	
	# Set initial position BEFORE adding to the tracking system
	# This prevents the enemy from lerping from (0,0)
	enemy.global_position = get_position_for_enemy(enemy)
	enemy.target_position = enemy.global_position  # Start at target, no lerp on spawn
	
	add_enemy(enemy)
	
	# Notify that enemy spawned
	Global.enemy_spawned.emit(enemy)
	
	return enemy

func spawn_enemies(enemy_data: EnemyData, count: int, spawn_range: int = 5) -> Array[Enemy]:
	var spawned: Array[Enemy] = []
	
	for i in count:
		var enemy = spawn_enemy(enemy_data, spawn_range)
		if enemy:
			spawned.append(enemy)
	
	return spawned

func add_enemy(enemy: Enemy):
	var range_num = enemy.get_current_range()
	
	if not enemies_by_range.has(range_num):
		enemies_by_range[range_num] = []
	
	if not enemies_by_range[range_num].has(enemy):
		enemies_by_range[range_num].append(enemy)
		enemy.enemy_moved.connect(_on_enemy_moved)

# =========================
# ITEM SUPPORT
# =========================

func add_item(item : Item):
	var range_num = item.get_current_range()
	
	if not items_by_range.has(range_num):
		items_by_range[range_num] = []
	
	if not items_by_range[range_num].has(item):
		items_by_range[range_num].append(item)
		_update_item_positions(range_num)

func remove_item(item : Item):
	var range_num = item.get_current_range()
	
	if items_by_range.has(range_num):
		items_by_range[range_num].erase(item)
		_update_item_positions(range_num)

func get_position_for_item(item : Item) -> Vector2:
	var range_num = item.get_current_range()
	var x_pos = _get_x_for_range(range_num)
	var y_pos = _get_y_for_item(item, range_num)
	return Vector2(x_pos, y_pos)

func _update_item_positions(range_num : int):
	if not items_by_range.has(range_num):
		return
	
	for item in items_by_range[range_num]:
		if item and item.has_method("update_target_position"):
			# Let the item update its own target position for smooth lerping
			item.update_target_position()

func _get_y_for_item(item : Item, range_num : int) -> float:
	var viewport_size = get_viewport().size
	var center_y = viewport_size.y * center_ratio
	
	if not item.has_meta("spawn_y"):
		item.set_meta("spawn_y", item.global_position.y if item.global_position.y != 0 else center_y + 120.0)
	return item.get_meta("spawn_y")
func spawn_item(item_data : ItemData, spawn_range : int, spawn_position : Vector2 = Vector2.ZERO):
	
	var item := Item.new()
	item.set_item(item_data)
	item.set_range(spawn_range)
	item.range_manager = self
	add_child(item)
	
	# Add to tracking first (so _get_y_for_item can calculate properly)
	if not items_by_range.has(spawn_range):
		items_by_range[spawn_range] = []
	items_by_range[spawn_range].append(item)
	
	# Set initial position AFTER adding to tracking
	if spawn_position != Vector2.ZERO:
		# Spawn at the specific position (e.g., where enemy died)
		item.global_position = spawn_position
		item.target_position = spawn_position
	else:
		# Default: spawn at the range position
		var calculated_pos = get_position_for_item(item)
		item.global_position = calculated_pos
		item.target_position = calculated_pos
	
	return item

# =========================

func remove_enemy(enemy: Enemy):
	var range_num = enemy.get_current_range()
	
	if enemies_by_range.has(range_num):
		enemies_by_range[range_num].erase(enemy)
		
		if enemy.enemy_moved.is_connected(_on_enemy_moved):
			enemy.enemy_moved.disconnect(_on_enemy_moved)

func get_position_for_enemy(enemy: Enemy) -> Vector2:
	var range_num = enemy.get_current_range()
	var x_pos = _get_x_for_range(range_num)
	var y_pos = _get_y_for_enemy(enemy, range_num)
   
	return Vector2(x_pos, y_pos)

func get_enemies_at_range(range_num: int):
	if enemies_by_range.has(range_num):
		return enemies_by_range[range_num]
	return []

func get_all_enemies() -> Array[Enemy]:
	var all_enemies: Array[Enemy] = []
	for range_num in enemies_by_range:
		all_enemies.append_array(enemies_by_range[range_num])
	return all_enemies

func _get_x_for_range(range_num: int) -> float:
	return range_num * range_spacing

func _get_y_for_enemy(enemy: Enemy, range_num: int) -> float:
	var enemies_at_range = enemies_by_range[range_num]
	var enemy_count = enemies_at_range.size()

	# Base center line
	var center_y = (get_viewport().size.y * center_ratio) - screen_buffer_y

	if enemy_count == 1:
		return center_y

	var enemy_index = enemies_at_range.find(enemy)
	if enemy_index == -1:
		return center_y

	# Dynamic spread
	var max_h = get_max_enemy_height(enemies_at_range)
	var total_spread = max_h * enemy_count * spread_multiplier
	var spacing = total_spread / (enemy_count - 1)
	var half_spread = total_spread / 2.0

	var base_y = center_y - half_spread + (enemy_index * spacing)

	# Wobble
	var wobble = sin(Time.get_ticks_msec() / 1000.0 * wobble_speed + enemy.get_instance_id()) * wobble_amplitude

	return base_y + wobble

func get_max_enemy_height(enemies):
	var max_h := 0.0
	for e in enemies:
		max_h = max(max_h, e.get_visual_height())
	return max_h

func _on_enemy_died(enemy: Enemy):
	remove_enemy(enemy)

func _on_enemy_moved(enemy: Enemy, old_range: int, new_range: int):
	if enemies_by_range.has(old_range):
		enemies_by_range[old_range].erase(enemy)
	
	if not enemies_by_range.has(new_range):
		enemies_by_range[new_range] = []
	
	if not enemies_by_range[new_range].has(enemy):
		enemies_by_range[new_range].append(enemy)

# ============================================================================
# TARGETING SYSTEM
# ============================================================================

func _input(event: InputEvent) -> void:
	if targeting:
		# Handle targeting input with higher priority
		if event.is_action_pressed("right click"):
			cancel_targeting()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("left click"):
			if enemy_hovered:
				toggle_target(enemy_hovered)
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			# Manual confirm with Enter/Space
			if targets.size() > 0:
				confirm_targets()
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	pass

func toggle_target(enemy: Enemy):
	if not enemy:
		return
	
	# Special handling for ALL_ENEMIES_AT_RANGE
	if current_target_type == Action.TargetType.ALL_ENEMIES_AT_RANGE:
		# Select all enemies at this enemy's range
		var enemy_range = enemy.get_current_range()
		targets.clear()
		
		var enemies_at_range = get_enemies_at_range(enemy_range)
		for e in enemies_at_range:
			targets.append(e)
			e.set_targeted(true)
		
		# Auto-confirm immediately
		confirm_targets()
		return
	
	# Normal toggle behavior for other target types
	# If enemy is already targeted, remove it
	if targets.has(enemy):
		targets.erase(enemy)
		enemy.set_targeted(false)
	# If we haven't reached the target limit, add it
	elif targets.size() < number_of_targets:
		targets.append(enemy)
		enemy.set_targeted(true)
	
	# Check if we have enough targets to auto-confirm
	# OR if we've selected all available enemies
	var selectable_count = _count_selectable_enemies()
	if targets.size() == number_of_targets or targets.size() == selectable_count:
		confirm_targets()

func _count_selectable_enemies() -> int:
	var count = 0
	for range_index in range(1, current_max_range + 1):
		count += get_enemies_at_range(range_index).size()
	return count

func start_targeting(target_type: Action.TargetType, max_range: int, num_targets: int):
	targeting = true
	current_target_type = target_type
	current_max_range = max_range
	number_of_targets = num_targets
	targets.clear()
	
	# Make appropriate enemies selectable based on target type
	match target_type:
		Action.TargetType.SINGLE_ENEMY, Action.TargetType.X_ENEMIES_UP_TO_RANGE:
			_make_enemies_selectable_up_to_range(max_range)
		Action.TargetType.ALL_ENEMIES_AT_RANGE:
			# For this type, player needs to select which range
			_make_all_ranges_selectable()
		Action.TargetType.ALL_ENEMIES:
			# This shouldn't need targeting - handled automatically
			pass
	
	targeting_started.emit()

func _make_enemies_selectable_up_to_range(max_range: int):
	for range_index in range(1, max_range + 1):
		var enemies_at_range = get_enemies_at_range(range_index)
		for enemy in enemies_at_range:
			enemy.make_selectable()

func _make_all_ranges_selectable():
	for range_index in enemies_by_range:
		var enemies_at_range = enemies_by_range[range_index]
		for enemy in enemies_at_range:
			enemy.make_selectable()

func cancel_targeting():
	targeting = false
	number_of_targets = 0
	
	# Clear all enemy states
	for enemy in get_all_enemies():
		enemy.make_unselectable()
		enemy.set_targeted(false)
	
	targets.clear()
	
	targeting_cancelled.emit()


func confirm_targets():
	targeting = false
	
	# Clear all enemy states
	for enemy in get_all_enemies():
		enemy.make_unselectable()
		enemy.set_targeted(false)
	
	# Emit signal with confirmed targets
	targets_confirmed.emit(targets)
