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
@export var noise_icon : Sprite2D
# Assign a Label to show the current noise value.
@export var noise_meter_label: Label

@export_category("Movement")
# When true, enemies advance one at a time (closest first) with a short delay
# between each so the player can see the order. When false, all move at once.
@export var sequential_movement: bool = false
# Seconds to wait between each enemy's move when sequential_movement is true.
@export var sequential_move_delay: float = 0.15

var current_win_condition: WinCondition = null

enum SpawnMode {
	IMMEDIATE,      # Cost added to noise meter, drained into spawns right away
	ENERGY_BANKED,  # Bank cost each card, add total to meter and drain on card draw
	TIERED,         # Cost added to noise meter, drained into spawns right away (same as IMMEDIATE)
	METER,          # Cost fills noise meter; time passing triggers drain + passive tick
	MIDDLE_GROUND   # Fraction of cost drains immediately; remainder charges meter for later
}
@export var spawn_mode: SpawnMode = SpawnMode.IMMEDIATE

var banked_energy: int = 0
var enemies_by_range: Dictionary = {}

# ── Noise meter ───────────────────────────────────────────────────────────────
# The noise level is the single source of truth for which enemy spawns.
# Enemies are selected deterministically: the highest noise_cost enemy that
# the current meter can afford is always chosen — no randomness involved.
# Elites are never part of this system; they must be spawned explicitly.
@export_category("Noise Meter")
# How much noise the combat opens with. Applied at _ready() in all spawn modes.
@export var starting_noise: float = 0.0
# Passive noise added each time the player passes time (METER mode only).
@export var passive_noise_per_turn: float = 2.0
# Minimum meter value required before a spawn attempt is made.
@export var noise_meter_spawn_threshold: float = 5.0
# MIDDLE_GROUND only: fraction of card cost that drains immediately.
# The remaining fraction charges the meter for later. 0.5 = half-and-half.
@export var immediate_cost_ratio: float = 0.5

var noise_meter: float = 0.0
var _last_noise_display: int = -1
var items_by_range : Dictionary = {}
var run_manager : RunManager

var enemy_hovered : Enemy
var targeting : bool = false
var targets : Array[Enemy] = []
var number_of_targets : int = 0
var current_target_type : Action.TargetType
var current_max_range : int = 0

# ── Elite enemy tracking ──────────────────────────────────────────────────────
# Elites are never selected by the noise system. They can only be spawned via
# explicit spawn_enemy() calls (e.g. from a scripted encounter or boss event).
# elite_spawned tracks whether one is already on the field to guard duplicates.
var elite_spawned: bool = false


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
		SpawnMode.IMMEDIATE, SpawnMode.TIERED:
			# Add cost to the meter and drain it immediately.
			noise_meter += cost
			_drain_meter_into_spawns()
		SpawnMode.ENERGY_BANKED:
			_bank_energy(cost)
		SpawnMode.METER:
			# Meter drains on time_passed, not card play.
			noise_meter += cost
		SpawnMode.MIDDLE_GROUND:
			_spawn_middle_ground(cost)

@export var camera: Camera2D

func _ready() -> void:
	add_to_group("range_manager")
	_recalculate_spacing()
	_initialize_ranges(5)
	Global.enemy_dies.connect(_on_enemy_died)
	Global.enemy_advanced.connect(_on_enemy_moved)
	Global.time_passed.connect(_on_time_passed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Seed starting noise and spawn from it on the first frame (all modes).
	if starting_noise > 0.0:
		noise_meter += starting_noise
		_drain_meter_into_spawns.call_deferred()

func _recalculate_spacing() -> void:
	var zoom_x := camera.zoom.x if camera else 1.0
	range_spacing = get_viewport_rect().size.x / (zoom_x * 6.0)
	# Keep the camera horizontally centred over all 6 ranges regardless of
	# viewport width. The Y position is set in the scene editor.
	if camera:
		camera.position.x = range_spacing * 3.0

func _on_viewport_size_changed() -> void:
	_recalculate_spacing()
	for range_num in enemies_by_range:
		_update_enemy_positions(range_num)
	for range_num in items_by_range:
		_update_item_positions(range_num)
	var character = get_tree().get_first_node_in_group("character")
	if character and character.has_method("position_character"):
		character.position_character()


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
	for i in range(5):  # boundaries: 0|1, 1|2, 2|3, 3|4, 4|5
		var x = (i + 1) * range_spacing
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

	# Noise label — updates only when the displayed integer changes,
	# and fires a brief scale-pop animation so the player notices the change.
	if noise_meter_label:
		var current_display := int(noise_meter)
		if current_display != _last_noise_display:
			_last_noise_display = current_display
			noise_meter_label.text = "%d" % current_display
			_animate_noise_label()

func _animate_noise_label() -> void:
	# Centre the pivot so the scale-pop grows from the middle of the label.
	noise_meter_label.pivot_offset = noise_meter_label.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)

	# Label: scale up then spring back.
	tween.tween_property(noise_meter_label, "scale", Vector2(1.45, 1.45), 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(noise_meter_label, "scale", Vector2(1.0, 1.0), 0.20) \
		.set_delay(0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Icon: flash to overbright white then settle back to normal.
	if noise_icon:
		tween.tween_property(noise_icon, "modulate", Color(2.5, 2.5, 1.8, 1.0), 0.06) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(noise_icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.30) \
			.set_delay(0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

func process_card_draw():
	if spawn_mode == SpawnMode.ENERGY_BANKED and banked_energy > 0:
		noise_meter += banked_energy
		banked_energy = 0
		_drain_meter_into_spawns()


func _bank_energy(amount: int):
	banked_energy += amount


func _spawn_middle_ground(cost: int):
	# Immediate fraction: drain that portion of the meter right now.
	var immediate_amount := cost * immediate_cost_ratio
	noise_meter += immediate_amount
	_drain_meter_into_spawns()

	# Remainder charges the meter to be drained on the next time_passed.
	noise_meter += cost - immediate_amount

# ── Noise meter handlers ──────────────────────────────────────────────────────

func _on_time_passed():
	match spawn_mode:
		SpawnMode.METER:
			# Passive tick: pressure builds even when the player plays cheaply.
			noise_meter += passive_noise_per_turn
			_drain_meter_into_spawns()
		SpawnMode.MIDDLE_GROUND:
			# No passive tick — only card costs charge the meter —
			# but drain whatever has accumulated from card plays this turn.
			_drain_meter_into_spawns()

	# Sequential movement: pick one enemy to advance this turn.
	if sequential_movement:
		_advance_one_enemy()

func _advance_one_enemy() -> void:
	# Sort by range ascending, then by column so the left column always
	# moves before the right column at the same range.
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

# ── Deterministic noise drain ─────────────────────────────────────────────────
# Drain the meter by spawning enemies in order of descending noise_cost.
# The enemy that spawns is always the most "expensive" one the current meter
# can afford — no randomness. Elites are never considered here.

func _drain_meter_into_spawns():
	var enemy_data := _pick_deterministic_enemy()
	while enemy_data != null and noise_meter >= enemy_data.noise_cost:
		spawn_enemy(enemy_data, 5)
		noise_meter -= enemy_data.noise_cost
		noise_meter = maxf(noise_meter, 0.0)
		enemy_data = _pick_deterministic_enemy()

func _pick_deterministic_enemy() -> EnemyData:
	# Return the enemy with the highest noise_cost the meter can currently
	# afford. Elites are included — a high enough noise level will trigger
	# them. The elite_spawned guard in spawn_enemy() prevents a second elite
	# from ever entering if one is already on the field.
	# Pool order breaks ties so the result is always the same for a given
	# meter value.
	var best: EnemyData = null
	var best_cost: float = -1.0

	for e: EnemyData in enemy_pool:
		if e.is_elite and elite_spawned:
			continue
		if e.noise_cost <= noise_meter and e.noise_cost > best_cost:
			best = e
			best_cost = e.noise_cost

	for tier in tiered_enemy_pools:
		var pool: Array = tiered_enemy_pools[tier]
		for e: EnemyData in pool:
			if e.is_elite and elite_spawned:
				continue
			if e.noise_cost <= noise_meter and e.noise_cost > best_cost:
				best = e
				best_cost = e.noise_cost

	return best  # null when meter is too low to afford anything

func _cheapest_available_noise_cost() -> float:
	# Returns the lowest noise_cost across all enemies that can still spawn.
	# Elites are included unless one has already spawned this combat.
	var cheapest := INF
	for e: EnemyData in enemy_pool:
		if e.is_elite and elite_spawned:
			continue
		cheapest = minf(cheapest, e.noise_cost)
	for tier in tiered_enemy_pools:
		for e: EnemyData in tiered_enemy_pools[tier]:
			if e.is_elite and elite_spawned:
				continue
			cheapest = minf(cheapest, e.noise_cost)
	return cheapest if cheapest < INF else INF

func spawn_enemy(enemy_data: EnemyData, spawn_range: int = 5) -> Enemy:
	if not enemy_scene:
		push_error("Enemy scene not assigned to RangeManager!")
		return null

	# ── Elite guard ───────────────────────────────────────────────────────────
	# Only one elite allowed per combat; block duplicates.
	if enemy_data.is_elite and elite_spawned:
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

	# ── Elite spawn hook ──────────────────────────────────────────────────────
	# Must run AFTER the enemy is fully added so win condition checks are valid.
	if enemy_data.is_elite:
		elite_spawned = true
		_on_elite_spawned(enemy)

	return enemy

# Called once when the first (and only) elite enemy enters the field.
# Replaces the active win condition with DefeatSingleEnemy targeting this elite,
# hides the progress bar (bool condition needs no bar), and fires a new announcement.
func _on_elite_spawned(elite: Enemy) -> void:
	# Tear down the old win condition's signal connections cleanly.
	if current_win_condition:
		current_win_condition.cleanup()

	# Build the elite-specific win condition.
	var elite_wc := DefeatSingleEnemy.new()
	elite_wc.target_enemy = elite
	elite_wc.initialize(run_manager)

	# Update both holders so every system sees the same object.
	current_win_condition = elite_wc
	if run_manager:
		run_manager.current_win_condition = elite_wc

	# Sync the HUD.
	if run_manager and run_manager.ui_bar and run_manager.ui_bar.has_method("set_win_condition"):
		run_manager.ui_bar.set_win_condition(elite_wc)

	# Defeating a single enemy is a bool — no progress fraction to display.
	if win_condition_bar:
		win_condition_bar.value = 0

	# Fire the new win condition announcement so the player knows the goal changed.
	if run_manager:
		var announcer := CombatAnnouncer.new()
		announcer.run_manager = run_manager
		run_manager.add_child(announcer)
		announcer.show_announcement(elite_wc.get_announcement_text(), "Elite Incoming!")

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
	return range_num * range_spacing + range_spacing * 0.5

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
