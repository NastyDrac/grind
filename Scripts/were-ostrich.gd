extends EnemyData
class_name WereOstrichData

# ── Phase config ──────────────────────────────────────────────────────────────
@export var day_turns  : int = 3
@export var night_turns: int = 3

# ── Night config ──────────────────────────────────────────────────────────────
@export var night_retreat_speed     : int = 2
@export var charge_damage_per_range : int = 8

# ── Movement speeds ───────────────────────────────────────────────────────────
const NORMAL_MOVE_SPEED  : float = 10.0
const RETREAT_MOVE_SPEED : float = 3.0   # Slow ominous retreat
const CHARGE_MOVE_SPEED  : float = 22.0  # Fast but readable charge

# ── Runtime state ─────────────────────────────────────────────────────────────
var is_night     : bool = false
var phase_turn   : int  = 0
var _day_damage  : int  = 0
var _day_speed   : int  = 0
var _initialized : bool = false


# ── Reset — called by enemy.gd on each new spawn ─────────────────────────────

func reset_movement_state() -> void:
	is_night     = false
	phase_turn   = 0
	_initialized = false
	_day_damage  = 0
	_day_speed   = 0


# ── EnemyData virtual methods ─────────────────────────────────────────────────

func override_movement(enemy) -> bool:
	if not _initialized:
		_day_damage  = enemy.data.damage
		_day_speed   = enemy.data.move_speed
		_initialized = true

	phase_turn += 1

	if not is_night:
		_do_day_move(enemy)
		if phase_turn >= day_turns:
			_enter_night(enemy)
	else:
		_do_night_move(enemy)
		if phase_turn >= night_turns:
			_enter_day(enemy)

	return true


## Called by enemy.get_next_intent() so the IntentIndicator stays accurate.
func get_current_intent() -> int:
	if not is_night:
		return MoveStep.MoveAction.ADVANCE
	if phase_turn >= night_turns - 1:
		return MoveStep.MoveAction.ATTACK  # Charge is next
	return MoveStep.MoveAction.RETREAT


## Called by enemy.get_intent_damage() for the IntentIndicator label.
## During night when a charge is imminent, returns the predicted charge damage
## based on the ostrich's current range so the value updates as it retreats.
func get_display_damage(enemy) -> int:
	if is_night and phase_turn >= night_turns - 1:
		var distance = enemy.current_range - 1
		return distance * charge_damage_per_range
	return enemy.get_attack_damage()


# ── Day phase ─────────────────────────────────────────────────────────────────

func _do_day_move(enemy) -> void:
	enemy.movement_speed = NORMAL_MOVE_SPEED
	if enemy.current_range <= enemy.data.attack_range:
		enemy.attack_player()
		return
	if randi() % 4 == 0:
		enemy._do_retreat()
	else:
		enemy._do_advance()


# ── Night phase ───────────────────────────────────────────────────────────────

func _do_night_move(enemy) -> void:
	if phase_turn >= night_turns:
		_do_charge(enemy)
	else:
		_do_night_retreat(enemy)

func _do_night_retreat(enemy) -> void:
	enemy.movement_speed = RETREAT_MOVE_SPEED
	const MAX_RANGE := 5
	var old_range = enemy.current_range
	enemy.current_range = min(MAX_RANGE, enemy.current_range + night_retreat_speed)
	if enemy.range_manager:
		enemy.target_position = enemy.range_manager.get_position_for_enemy(enemy)
	Global.enemy_advanced.emit(enemy, old_range, enemy.current_range)

func _do_charge(enemy) -> void:
	_spawn_charge_trail(enemy)

	var old_range = enemy.current_range
	var distance  = enemy.current_range - 1

	enemy.movement_speed = CHARGE_MOVE_SPEED
	enemy.current_range = 1
	if enemy.range_manager:
		enemy.target_position = enemy.range_manager.get_position_for_enemy(enemy)
	Global.enemy_advanced.emit(enemy, old_range, enemy.current_range)

	var dmg = distance * charge_damage_per_range
	if dmg > 0:
		Global.enemy_attacks_player.emit(enemy, dmg)


# ── Phase transitions ─────────────────────────────────────────────────────────

func _enter_night(enemy) -> void:
	is_night   = true
	phase_turn = 0
	enemy.data.damage     = 0
	enemy.data.move_speed = night_retreat_speed
	enemy.movement_speed  = RETREAT_MOVE_SPEED
	_announce(enemy, "Night Falls", "The Were-Ostrich!")

func _enter_day(enemy) -> void:
	is_night   = false
	phase_turn = 0
	enemy.data.damage     = _day_damage
	enemy.data.move_speed = _day_speed
	enemy.movement_speed  = NORMAL_MOVE_SPEED
	_announce(enemy, "Dawn Breaks", "The Ostrich!")


# ── Charge trail ──────────────────────────────────────────────────────────────
# Spawns ghost sprites at evenly spaced positions between the ostrich's current
# position and range 1, giving a visible smear across the board.

func _spawn_charge_trail(enemy) -> void:
	var sprite_node = enemy.get_node_or_null("Sprite2D")
	if not sprite_node or not enemy.range_manager:
		return

	# Start: where the enemy currently is (local space, enemy is child of range_manager)
	var start_pos = enemy.position

	# End: position at range 1 in range_manager local space
	var end_x = enemy.range_manager._get_x_for_range(1)
	var end_pos := Vector2(end_x, enemy.position.y)

	var num_ghosts := 6
	for i in range(num_ghosts):
		var t     := float(i) / float(num_ghosts - 1)
		var ghost := Sprite2D.new()
		ghost.texture  = sprite_node.texture
		ghost.scale    = sprite_node.scale
		ghost.position = start_pos.lerp(end_pos, t)
		ghost.z_index  = 4
		ghost.modulate = Color(1.0, 0.55, 0.1, 0.65 - t * 0.45)
		enemy.range_manager.add_child(ghost)

		var tween = enemy.range_manager.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.5)
		tween.tween_callback(ghost.queue_free)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _announce(enemy, title: String, subtitle: String) -> void:
	if not enemy.range_manager or not enemy.range_manager.run_manager:
		return
	var announcer         := CombatAnnouncer.new()
	announcer.run_manager  = enemy.range_manager.run_manager
	enemy.range_manager.run_manager.add_child(announcer)
	announcer.show_announcement(title, subtitle)
