extends Node
class_name AnimationManager


func _ready() -> void:
	add_to_group("animation_manager")
	Global.request_animation.connect(_on_animation_requested)




## Fire a projectile from `from` to `target`, then call `on_hit` once it lands.
## The caller does NOT need to await — this is self-contained.
##
## Example (turret):
##   AnimationManager.fire_projectile(
##       _sprite.global_position, target,
##       func(): target.take_damgage(damage.calculate(player))
##   )
func fire_projectile(from: Vector2, target: Node2D, on_hit: Callable) -> void:
	await _play_projectile(from, target.global_position, target)
	if is_instance_valid(target):
		on_hit.call()


func _on_animation_requested(action: Action, target: Object, anim_type: Action.AnimationType) -> void:
	var player_pos := _get_player_position()
	var target_pos := _get_target_position(target)

	match anim_type:
		Action.AnimationType.PROJECTILE:
			await _play_projectile(player_pos, target_pos, target)
		Action.AnimationType.MELEE_SLASH:
			await _play_melee_slash(target_pos, target)
		Action.AnimationType.AOE_BURST:
			await _play_aoe_burst(target_pos, target)
		Action.AnimationType.BUFF:
			await _play_buff(player_pos)

	# Signal the action that the visual is done — damage now applies.
	action.animation_done.emit()


# ============================================================================
# POSITION HELPERS
# ============================================================================

func _get_player_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return Vector2(100.0, get_viewport().size.y * 0.5)

	# Player is a plain Node — find its Sprite2D child for a real screen position.
	for child in player.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return (child as Node2D).global_position

	# Fallback: player itself might be a Node2D subclass.
	if player is Node2D:
		return (player as Node2D).global_position

	# Last resort: fixed left-side position.
	return Vector2(100.0, get_viewport().size.y * 0.5)


func _get_target_position(target: Object) -> Vector2:
	if is_instance_valid(target) and target is Node2D:
		return (target as Node2D).global_position
	return get_viewport().size * 0.5

func _spawn(node: Node) -> void:
	add_child(node)


# ============================================================================
# PROJECTILE
# ============================================================================
# A small bright square travels from the player to the target.
# Damage is held back until the square arrives and the enemy flashes red.
#
# To replace with a real sprite later:
#   - Remove the ColorRect creation.
#   - Instantiate your projectile scene instead and tween its global_position.

func _play_projectile(from: Vector2, to: Vector2, target: Object) -> void:
	# --- Build the projectile dot ---
	var proj := ColorRect.new()
	proj.size = Vector2(14.0, 14.0)
	proj.pivot_offset = proj.size * 0.5
	proj.color = Color(1.0, 0.85, 0.1)   # Warm yellow
	proj.z_index = 200
	_spawn(proj)
	proj.global_position = from - proj.pivot_offset

	# --- Travel ---
	var travel := create_tween()
	travel.tween_property(proj, "global_position", to - proj.pivot_offset, .2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await travel.finished
	proj.queue_free()

	# --- Impact flash --- (await here keeps damage locked until flash starts)
	if is_instance_valid(target) and target is Node2D:
		await _flash_red(target as Node2D, 0.18)


# ============================================================================
# MELEE SLASH
# ============================================================================
# Three diagonal Line2Ds snap onto the target in a fan, then fade out.
# The target flashes red at the same moment the lines appear.
#
# To replace with a real sprite later:
#   - Instantiate a Sprite2D with your slash texture.
#   - Tween its scale from 0→1 then modulate:a from 1→0.

func _play_melee_slash(at: Vector2, target: Object) -> void:
	# Each entry: [point_a, point_b, color]
	var slash_defs := [
		[Vector2(-45.0, -35.0), Vector2(45.0,  35.0), Color(1.00, 1.00, 1.00, 0.95)],  # \
		[Vector2(-45.0,   0.0), Vector2(45.0,   0.0), Color(0.80, 0.85, 1.00, 0.85)],  # —
		[Vector2(-45.0,  35.0), Vector2(45.0, -35.0), Color(1.00, 1.00, 1.00, 0.95)],  # /
	]

	var lines: Array[Line2D] = []
	for def in slash_defs:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = def[2]
		line.add_point(def[0])
		line.add_point(def[1])
		line.global_position = at
		line.modulate.a = 0.0
		line.z_index = 200
		_spawn(line)
		lines.append(line)

	# Flash and slashes run concurrently — don't await the flash.
	if is_instance_valid(target) and target is Node2D:
		_flash_red(target as Node2D, 0.14)

	# Staggered appear → hold → fade for each slash line.
	for i in lines.size():
		var line := lines[i]
		var tween := create_tween()
		tween.tween_interval(i * 0.04)
		tween.tween_property(line, "modulate:a", 1.0, 0.04)
		tween.tween_interval(0.1)
		tween.tween_property(line, "modulate:a", 0.0, 0.2)

	# Wait for the full animation to complete before damage applies.
	await get_tree().create_timer(0.44).timeout

	for line in lines:
		if is_instance_valid(line):
			line.queue_free()


# ============================================================================
# AOE BURST
# ============================================================================
# Small squares erupt outward from the target in 8 directions and fade
# as they travel. The target flashes red at the moment of eruption.
#
# Note: card_handler calls play_animation_and_execute() once per enemy,
# so on ALL_ENEMIES cards each enemy gets its own burst in sequence.
# If you want a single simultaneous burst for all enemies later, the
# architecture change is in _execute_action_on_targets() in card_handler.
#
# To replace with real particles later:
#   - Swap the ColorRect loop for a CPUParticles2D with one_shot = true.

func _play_aoe_burst(at: Vector2, target: Object) -> void:
	const NUM_SHARDS  := 8
	const TRAVEL_DIST := 90.0
	const DURATION    := 0.30

	var shards: Array[ColorRect] = []

	for i in NUM_SHARDS:
		var angle := (TAU / NUM_SHARDS) * i
		var dir   := Vector2(cos(angle), sin(angle))

		var shard := ColorRect.new()
		shard.size         = Vector2(12.0, 12.0)
		shard.pivot_offset = shard.size * 0.5
		# Cycle through orange tones for variety.
		shard.color  = Color(1.0, 0.35 + (i % 3) * 0.15, 0.05)
		shard.z_index = 200
		_spawn(shard)
		shard.global_position = at - shard.pivot_offset

		var end_pos := at + dir * TRAVEL_DIST - shard.pivot_offset
		var tween   := create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", end_pos, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate:a", 0.0, DURATION) \
			.set_trans(Tween.TRANS_LINEAR)

		shards.append(shard)

	# Await the flash so damage lands after the burst starts.
	if is_instance_valid(target) and target is Node2D:
		await _flash_red(target as Node2D, 0.15)
	else:
		await get_tree().create_timer(DURATION).timeout

	for shard in shards:
		if is_instance_valid(shard):
			shard.queue_free()


# ============================================================================
# BUFF
# ============================================================================
# Soft coloured motes float upward and fade from the player's position.
# No enemy target is involved — damage/effect applies after the rise.
#
# To replace with real particles later:
#   - Use a CPUParticles2D pointed upward with one_shot = true.

func _play_buff(at: Vector2) -> void:
	const NUM_MOTES := 9
	const DURATION  := 0.55

	var mote_colors := [
		Color(0.30, 0.85, 1.00),  # Cyan
		Color(0.50, 1.00, 0.55),  # Green
		Color(1.00, 1.00, 0.35),  # Yellow
	]

	var motes: Array[ColorRect] = []

	for i in NUM_MOTES:
		var mote := ColorRect.new()
		mote.size         = Vector2(9.0, 9.0)
		mote.pivot_offset = mote.size * 0.5
		mote.color        = mote_colors[i % mote_colors.size()]
		mote.z_index      = 200

		var offset := Vector2(randf_range(-35.0, 35.0), randf_range(-10.0, 15.0))
		mote.global_position = at + offset - mote.pivot_offset
		_spawn(mote)
		motes.append(mote)

		var delay   := i * 0.045
		var rise    := Vector2(randf_range(-18.0, 18.0), randf_range(-70.0, -110.0))
		var end_pos := mote.global_position + rise

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "global_position", end_pos, DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "modulate:a", 0.0, DURATION * 0.75) \
			.set_delay(delay + DURATION * 0.25)

	# Wait for the last mote to finish before applying the buff effect.
	await get_tree().create_timer(DURATION + NUM_MOTES * 0.045).timeout

	for mote in motes:
		if is_instance_valid(mote):
			mote.queue_free()


# ============================================================================
# SHARED UTILITY
# ============================================================================

# Flashes a node to bright red then returns to its original colour.
# Can be called with `await` (blocks caller) or without (runs concurrently).
func _flash_red(node: Node2D, duration: float) -> void:
	var original := node.modulate
	var tween    := create_tween()
	# Overshoot past 1.0 so it's noticeably bright even on coloured sprites.
	tween.tween_property(node, "modulate", Color(1.8, 0.25, 0.25), duration * 0.3) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", original, duration * 0.7) \
		.set_trans(Tween.TRANS_SINE)
	await tween.finished

# ============================================================================
# HEAL  — paste this block directly below _play_buff() in animation_manager.gd
# ============================================================================
# Bright green motes rise from the target and a soft green flash washes over it.
# Called directly from HealCondition — no Action or signal needed.

func play_heal(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var at := target.global_position
	_play_heal_motes(at)
	_flash_green(target, 0.30)


func _play_heal_motes(at: Vector2) -> void:
	const NUM_MOTES := 8
	const DURATION  := 0.50

	var green_tones := [
		Color(0.20, 1.00, 0.40),   # Bright green
		Color(0.35, 0.90, 0.35),   # Mid green
		Color(0.55, 1.00, 0.20),   # Yellow-green
	]

	var motes : Array[ColorRect] = []

	for i in NUM_MOTES:
		var mote := ColorRect.new()
		mote.size         = Vector2(10.0, 10.0)
		mote.pivot_offset = mote.size * 0.5
		mote.color        = green_tones[i % green_tones.size()]
		mote.z_index      = 200

		var offset  := Vector2(randf_range(-30.0, 30.0), randf_range(-5.0, 20.0))
		mote.global_position = at + offset - mote.pivot_offset
		_spawn(mote)
		motes.append(mote)

		var delay   := i * 0.04
		var rise    := Vector2(randf_range(-15.0, 15.0), randf_range(-60.0, -100.0))
		var end_pos := mote.global_position + rise

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "global_position", end_pos, DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "modulate:a", 0.0, DURATION * 0.75) \
			.set_delay(delay + DURATION * 0.25)

	await get_tree().create_timer(DURATION + NUM_MOTES * 0.04).timeout

	for mote in motes:
		if is_instance_valid(mote):
			mote.queue_free()


## Flashes the target node to bright green then fades back to its original colour.
## Can be awaited or called fire-and-forget.
func _flash_green(node: Node2D, duration: float) -> void:
	var original := node.modulate
	var tween    := create_tween()
	tween.tween_property(node, "modulate", Color(0.25, 1.80, 0.40), duration * 0.3) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", original, duration * 0.7) \
		.set_trans(Tween.TRANS_SINE)
	await tween.finished
