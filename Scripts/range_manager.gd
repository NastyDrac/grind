extends Node2D
class_name RangeManager
@export var spread_multiplier : float = .6
@export var range_spacing: float = 225.0
@export var y_spread_min: float = -400.0
@export var y_spread_max: float = 100.0
@export var enemy_scene: PackedScene = preload("res://Scenes/enemy.tscn")
@export var screen_buffer_y : float = 75.0
## Hard Y boundaries for enemy placement. Enemies will never be positioned
## outside this band, no matter how many are stacked in a range.
## y_min is the topmost pixel enemies may occupy (0 = top of viewport).
## y_max is the bottommost pixel — set this above your card UI area.
@export var y_min: float = 80.0
@export var y_max: float = 520.0
## Horizontal separation (in pixels) between the two columns inside a range.
## Each column is placed this many pixels left/right of the range centre.
@export var column_x_offset: float = 35.0
## How many enemies fill the left column before any spill into the right column.
@export var max_per_column: int = 4
@export var wobble_speed := 1.0
@export var wobble_amplitude := 2.5

@export var enemy_pool: Array[EnemyData] = []
@export var tiered_enemy_pools: Dictionary = {} 
@export var center_ratio := .4

# How far past the right edge enemies spawn from (pixels beyond viewport width)
@export var entry_offscreen_margin: float = 200.0

# Visual style for range divider lines
@export var range_line_color: Color = Color(1, 1, 1, 0.15)
@export var range_line_width: float = 2.0

@export_category("UI")
# Assign a ProgressBar node from your scene to display win condition progress.
@export var win_condition_bar: TextureProgressBar
# Assign a Label node to display the win condition text (e.g. "12 / 20 kills").
@export var win_condition_label: Label
# Assign a ProgressBar node to display the current noise meter level.
@export var noise_meter_bar: TextureProgressBar
# Assign a Label to show exact noise meter value next to the bar.
@export var noise_meter_label: Label

@export_category("Movement")
# When true, enemies advance one at a time (closest first) with a short delay
# between each so the player can see the order. When false, all move at once.
@export var sequential_movement: bool = false
# Seconds to wait between each enemy's move when sequential_movement is true.
@export var sequential_move_delay: float = 0.15

var current_win_condition: WinCondition = null

enum SpawnMode {
	IMMEDIATE,      # Cost = enemy count, spawn from enemy_pool right away
	ENERGY_BANKED,  # Bank cost each card, dump the total into spawns on card draw
	TIERED,         # Cost determines enemy tier, spawns one tiered enemy immediately
	METER,          # Cost fills a noise meter; time passing triggers weighted spawns + passive tick
	MIDDLE_GROUND   # Fraction of cost spawns cheap enemies immediately; remainder charges the meter for harder enemies
}
@export var spawn_mode: SpawnMode = SpawnMode.IMMEDIATE

var banked_energy: int = 0
var enemies_by_range: Dictionary = {}

# ── Noise meter (METER and MIDDLE_GROUND modes) ──────────────────────────────
# Passive noise added to the meter each time the player passes time.
# Ensures pressure builds even when the player plays cheaply.
@export_category("Noise Meter")
@export var passive_noise_per_turn: float = 2.0
# Meter must reach this value before a spawn attempt is made.
@export var noise_meter_spawn_threshold: float = 5.0
# MIDDLE_GROUND only: fraction of card cost that spawns enemies immediately.
# The remaining fraction charges the meter. 0.5 = half-and-half.
@export var immediate_cost_ratio: float = 0.5

var noise_meter: float = 0.0
var items_by_range : Dictionary = {}
var run_manager : RunManager

var enemy_hovered : Enemy
var targeting : bool = false
var targets : Array[Enemy] = []
var number_of_targets : int = 0
var current_target_type : Action.TargetType
var current_max_range : int = 0


signal targeting_started()
signal targeting_cancelled()
signal targets_confirmed(targets: Array[Enemy])

func set_win_condition(wc: WinCondition) -> void:
	current_win_condition = wc

func _initialize_ranges(max_range: int):
	for i in range(max_range + 1):
		enemies_by_range[i] = []
		items_by_range[i] = []


func process_card_cost(cost: int):
	match spawn_mode:
		SpawnMode.IMMEDIATE:
			_spawn_immediate(cost)
		SpawnMode.ENERGY_BANKED:
			_bank_energy(cost)
		SpawnMode.TIERED:
			_spawn_tiered(cost)
		SpawnMode.METER:
			noise_meter += cost
		SpawnMode.MIDDLE_GROUND:
			_spawn_middle_ground(cost)

func _ready() -> void:
	range_spacing = get_viewport_rect().size.x / 5
	add_to_group("range_manager")
	_initialize_ranges(5)
	if spawn_mode != SpawnMode.METER:
		noise_meter_bar.visible = false
	Global.enemy_dies.connect(_on_enemy_died)
	Global.enemy_advanced.connect(_on_enemy_moved)
	Global.time_passed.connect(_on_time_passed)

func _process(_delta: float) -> void:
	queue_redraw()
	_update_ui()

# =========================
# RANGE DIVIDER LINES
# =========================

func _draw() -> void:
	var viewport_size = get_viewport().size
	var top_y    = -200.0
	var bottom_y = viewport_size.y

	# Draw a vertical line between each pair of adjacent ranges.
	for i in range(5):  # gaps: 0-1, 1-2, 2-3, 3-4, 4-5
		var x = (i * range_spacing) + range_spacing * 0.5
		draw_line(
			Vector2(x, top_y),
			Vector2(x, bottom_y),
			range_line_color,
			range_line_width
		)

# =========================
# UI UPDATES
# =========================

func _update_ui() -> void:
	# Win condition bar
	if current_win_condition != null:
		if win_condition_bar:
			var fraction := 0.0
			if current_win_condition.has_method("get_progress_fraction"):
				fraction = current_win_condition.get_progress_fraction()
			win_condition_bar.value = fraction * win_condition_bar.max_value
		if win_condition_label:
			win_condition_label.text = current_win_condition.get_progress_text()

	# Noise meter bar (only meaningful in METER / MIDDLE_GROUND modes)
	if noise_meter_bar:
		noise_meter_bar.max_value = noise_meter_spawn_threshold
		noise_meter_bar.value = minf(noise_meter, noise_meter_spawn_threshold)
	if noise_meter_label:
		noise_meter_label.text = "Noise: %d / %d" % [int(noise_meter), int(noise_meter_spawn_threshold)]

func process_card_draw():
	if spawn_mode == SpawnMode.ENERGY_BANKED and banked_energy > 0:
		_spawn_immediate(banked_energy)
		banked_energy = 0


func _spawn_immediate(count: int):
	if enemy_pool.is_empty():
		push_warning("Enemy pool is empty!")
		return
	
	for i in count:
		var random_enemy = enemy_pool.pick_random()
		spawn_enemy(random_enemy, 5)


func _bank_energy(amount: int):
	banked_energy += amount


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

# ── Noise meter handlers ──────────────────────────────────────────────────────

func _on_time_passed():
	match spawn_mode:
		SpawnMode.METER:
			# Ambient noise: pressure builds passively even with cheap play
			noise_meter += passive_noise_per_turn
			_drain_meter_into_spawns()
		SpawnMode.MIDDLE_GROUND:
			# No passive tick — only card costs charge the middle-ground meter —
			# but we still drain whatever has accumulated this turn.
			_drain_meter_into_spawns()

	# Sequential movement: range_manager picks one enemy to advance this turn.
	# Enemy._on_enemies_advance() returns early when sequential_movement is true
	# so only the enemy chosen here actually moves.
	if sequential_movement:
		_advance_one_enemy()

func _advance_one_enemy() -> void:
	# Sort by range ascending, then by column (left before right) so enemies
	# in the left column always move before those in the right column.
	var all := get_all_enemies().filter(func(e): return is_instance_valid(e))
	all.sort_custom(func(a, b):
		if a.get_current_range() != b.get_current_range():
			return a.get_current_range() < b.get_current_range()
		return _get_enemy_column(a) < _get_enemy_column(b)
	)

	for enemy in all:
		if is_instance_valid(enemy):
			enemy.move_toward_player()
			await get_tree().create_timer(sequential_move_delay).timeout

func _get_enemy_column(enemy: Enemy) -> int:
	var range_num := enemy.get_current_range()
	if not enemies_by_range.has(range_num):
		return 0
	var at_range: Array = enemies_by_range[range_num].filter(
		func(e): return is_instance_valid(e)
	)
	var idx := at_range.find(enemy)
	return idx % 2 if idx != -1 else 0

func _spawn_middle_ground(cost: int):
	# Immediate half: cheap enemies spawn right now from the basic pool
	var immediate_count := int(cost * immediate_cost_ratio)
	for i in immediate_count:
		if not enemy_pool.is_empty():
			spawn_enemy(enemy_pool.pick_random(), 5)
	
	# Remainder: charges the meter toward harder enemies
	noise_meter += cost - immediate_count

func _drain_meter_into_spawns():
	# Keep spending meter budget until we can no longer afford anything.
	# Each spawn deducts that enemy's noise_cost from the meter, so the meter
	# acts as a currency rather than a simple threshold.
	var cheapest := _cheapest_available_noise_cost()
	while noise_meter >= cheapest:
		var enemy_data := _pick_weighted_enemy()
		if enemy_data == null:
			break
		# Don't overspend — skip enemies we can't afford this cycle
		if enemy_data.noise_cost > noise_meter:
			continue
		spawn_enemy(enemy_data, 5)
		noise_meter -= enemy_data.noise_cost
		noise_meter = max(noise_meter, 0.0)
		cheapest = _cheapest_available_noise_cost()

func _pick_weighted_enemy() -> EnemyData:
	# Build a candidate list where each enemy appears a number of times
	# proportional to how affordable it is relative to the current meter.
	# This means cheap enemies are always possible, but as the meter grows
	# expensive enemies become increasingly likely — without being guaranteed.
	var candidates: Array = []
	
	# Base pool (cheapest enemies) — always included
	for e: EnemyData in enemy_pool:
		candidates.append(e)
	
	# Tiered pool — include tiers the meter can afford, weighted by headroom.
	# An ogre that costs 5 gets 1 entry at meter=5, 3 entries at meter=15, etc.
	for tier in tiered_enemy_pools:
		if noise_meter >= tier:
			var pool: Array = tiered_enemy_pools[tier]
			var weight := int((noise_meter - tier) / noise_meter_spawn_threshold) + 1
			weight = clamp(weight, 1, 6)
			for i in weight:
				for e: EnemyData in pool:
					candidates.append(e)
	
	if candidates.is_empty():
		push_warning("RangeManager: no enemies available to pick from noise meter.")
		return null
	
	return candidates.pick_random()

func _cheapest_available_noise_cost() -> float:
	# Returns the lowest noise_cost across all pools so we know when to stop draining.
	var cheapest := INF
	for e: EnemyData in enemy_pool:
		cheapest = min(cheapest, e.noise_cost)
	for tier in tiered_enemy_pools:
		for e: EnemyData in tiered_enemy_pools[tier]:
			cheapest = min(cheapest, e.noise_cost)
	return cheapest if cheapest < INF else INF

func spawn_enemy(enemy_data: EnemyData, spawn_range: int = 5) -> Enemy:
	if not enemy_scene:
		push_error("Enemy scene not assigned to RangeManager!")
		return null
	
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.data = enemy_data
	add_child(enemy)
	enemy.set_data(enemy_data, spawn_range)
	
	enemy.set_range_manager(self)
	
	# Where the enemy should ultimately stand
	var destination := get_position_for_enemy(enemy)
	enemy.target_position = destination

	# Start the enemy off the far right of the screen so it travels in
	var viewport_width = get_viewport().size.x
	enemy.global_position = Vector2(viewport_width + entry_offscreen_margin, destination.y)
	
	add_enemy(enemy)
	
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
		_update_enemy_positions(range_num)

# =========================
# POSITION HELPERS
# =========================

func _update_enemy_positions(range_num: int):
	if not enemies_by_range.has(range_num):
		return
	for enemy in enemies_by_range[range_num]:
		if is_instance_valid(enemy):
			enemy.target_position = get_position_for_enemy(enemy)

# =========================
# ITEM SUPPORT
# =========================
func get_all_items():
	var all_items: Array[Item] = []
	for range_num in items_by_range:
		for e in items_by_range[range_num]:
			if is_instance_valid(e):
				all_items.append(e)
	return all_items
	
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
	# Offset by half a range_spacing so items sit on the divider lines
	# that fall between enemy columns, rather than overlapping the enemies.
	var x_pos = _get_x_for_range(range_num) + range_spacing * 0.5
	var y_pos = _get_y_for_item(item, range_num)
	return Vector2(x_pos, y_pos)

func _update_item_positions(range_num : int):
	if not items_by_range.has(range_num):
		return
	
	for item in items_by_range[range_num]:
		if item and item.has_method("update_target_position"):
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
	
	if not items_by_range.has(spawn_range):
		items_by_range[spawn_range] = []
	items_by_range[spawn_range].append(item)
	
	if spawn_position != Vector2.ZERO:
		item.global_position = spawn_position
		item.target_position = spawn_position
	else:
		var calculated_pos = get_position_for_item(item)
		item.global_position = calculated_pos
		item.target_position = calculated_pos
	
	return item

# =========================

func remove_enemy(enemy: Enemy):
	var range_num = enemy.get_current_range()
	
	if enemies_by_range.has(range_num):
		enemies_by_range[range_num].erase(enemy)

func get_position_for_enemy(enemy: Enemy) -> Vector2:
	var range_num = enemy.get_current_range()
	var base_x   = _get_x_for_range(range_num)

	# Filter out any freed instances before doing layout math
	var enemies_at_range: Array = enemies_by_range[range_num].filter(
		func(e): return is_instance_valid(e)
	)

	var enemy_index: int = enemies_at_range.find(enemy)
	if enemy_index == -1:
		return Vector2(base_x, (y_min + y_max) * 0.5)

	var enemy_count: int = enemies_at_range.size()

	# ── Two-column layout ────────────────────────────────────────────────────
	# Fill the left column up to max_per_column enemies before using the right.
	# Y positions stay within [y_min, y_max] — enemies can never leave that band.
	# Alternating assignment keeps columns even: even indices go left, odd go right.
	# Left always gets the extra enemy when the count is odd.
	var col: int       = enemy_index % 2       # 0 = left, 1 = right
	var col_index: int = enemy_index / 2       # position within that column

	# Only apply an X offset when there are multiple enemies.
	var x_offset: float = 0.0
	if enemy_count > 1:
		x_offset = column_x_offset * (1.0 if col == 1 else -1.0)
	var x_pos: float = base_x + x_offset

	# Left gets ceil(n/2), right gets floor(n/2) — always balanced.
	var left_count: int     = ceili(float(enemy_count) / 2.0)
	var right_count: int    = enemy_count / 2
	var this_col_count: int = left_count if col == 0 else right_count

	# Spread this column's enemies evenly within [y_min, y_max].
	var y_pos: float
	if this_col_count <= 1:
		y_pos = (y_min + y_max) * 0.5
	else:
		var spacing: float = (y_max - y_min) / float(this_col_count - 1)
		y_pos = y_min + col_index * spacing

	# Subtle wobble so the group looks alive (always clamped to safe zone).
	var wobble: float = sin(
		Time.get_ticks_msec() / 1000.0 * wobble_speed + enemy.get_instance_id()
	) * wobble_amplitude

	return Vector2(x_pos, clamp(y_pos + wobble, y_min, y_max))

func get_enemies_at_range(range_num: int):
	if enemies_by_range.has(range_num):
		return enemies_by_range[range_num]
	return []

func get_all_enemies() -> Array[Enemy]:
	var all_enemies: Array[Enemy] = []
	for range_num in enemies_by_range:
		for e in enemies_by_range[range_num]:
			if is_instance_valid(e):
				all_enemies.append(e)
	return all_enemies

func _get_x_for_range(range_num: int) -> float:
	return range_num * range_spacing

# _get_y_for_enemy is superseded by the two-column logic inside
# get_position_for_enemy and is no longer called. Kept as a stub so any
# external call-sites don't hard-crash before they can be updated.
func _get_y_for_enemy(enemy: Enemy, range_num: int) -> float:
	return get_position_for_enemy(enemy).y

func get_max_enemy_height(enemies):
	var max_h := 0.0
	for e in enemies:
		if is_instance_valid(e):
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

	# Reflow layouts at both ranges so all enemies reposition
	_update_enemy_positions(old_range)
	_update_enemy_positions(new_range)

# ============================================================================
# TARGETING SYSTEM
# ============================================================================

func _input(event: InputEvent) -> void:
	if targeting:
		if event.is_action_pressed("right click"):
			cancel_targeting()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("left click"):
			if enemy_hovered:
				toggle_target(enemy_hovered)
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if targets.size() > 0:
				confirm_targets()
				get_viewport().set_input_as_handled()


func toggle_target(enemy: Enemy):
	if not enemy:
		return

	# Reject clicks on enemies outside the card's declared range.
	var enemy_range := enemy.get_current_range()
	if current_max_range > 0 and enemy_range > current_max_range:
		return

	if current_target_type == Action.TargetType.ALL_ENEMIES_AT_RANGE:
		targets.clear()

		var enemies_at_range = get_enemies_at_range(enemy_range)
		for e in enemies_at_range:
			targets.append(e)
			e.set_targeted(true)

		confirm_targets()
		return

	if targets.has(enemy):
		targets.erase(enemy)
		enemy.set_targeted(false)
	elif targets.size() < number_of_targets:
		targets.append(enemy)
		enemy.set_targeted(true)
	
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
	
	match target_type:
		Action.TargetType.SINGLE_ENEMY, Action.TargetType.X_ENEMIES_UP_TO_RANGE:
			_make_enemies_selectable_up_to_range(max_range)
		Action.TargetType.ALL_ENEMIES_AT_RANGE:
			_make_enemies_selectable_up_to_range(max_range)
		Action.TargetType.ALL_ENEMIES:
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
	
	for enemy in get_all_enemies():
		enemy.make_unselectable()
		enemy.set_targeted(false)
	
	targets.clear()
	targeting_cancelled.emit()


func confirm_targets():
	targeting = false
	
	for enemy in get_all_enemies():
		enemy.make_unselectable()
		enemy.set_targeted(false)
	
	targets_confirmed.emit(targets)
