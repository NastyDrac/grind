extends Condition
class_name TriggeredCondition

enum TriggerType {
	ON_DEATH,
	ON_ATTACK,
	ON_ADVANCE
}

enum TargetType {
	ATTACK_TARGET,         ## The player (whoever the enemy attacked)
	ALL_ENEMIES,           ## Every enemy currently on the field
	ALL_OTHER_ENEMIES,     ## Every enemy except self
	ALL_ENEMIES_AT_RANGE   ## Every enemy at the same range as self
}

@export_group("Trigger")
@export var trigger_type : TriggerType = TriggerType.ON_DEATH

@export_group("Target")
@export var target_type : TargetType = TargetType.ATTACK_TARGET

@export_group("Effect")
## The condition applied to resolved targets when triggered.
@export var triggered_effect : Condition

@export_group("Advance Settings")
## If true, fires every time the enemy moves.
## If false, only fires when the enemy reaches trigger_range.
@export var fire_every_advance : bool = true
@export var trigger_range : int = 1
var targets : Array = []

func apply_condition(who, condition: Condition) -> void:
	entity = who
	var existing = get_existing_condition(who, self)
	if existing == null:
		var new_cond : TriggeredCondition = condition.duplicate(true)
		new_cond.entity = who
		new_cond.stacks = condition.stacks
		who.conditions.append(new_cond)
		new_cond._connect_trigger()
	else:
		existing.stacks += condition.stacks
	

func _connect_trigger() -> void:
	match trigger_type:
		TriggerType.ON_DEATH:
			Global.enemy_dies.connect(_on_enemy_dies)
		TriggerType.ON_ATTACK:
			Global.enemy_attacks_player.connect(_on_enemy_attacks)
		TriggerType.ON_ADVANCE:
			Global.enemy_advanced.connect(_on_enemy_advanced)
			


func _disconnect_trigger() -> void:
	match trigger_type:
		TriggerType.ON_DEATH:
			if Global.enemy_dies.is_connected(_on_enemy_dies):
				Global.enemy_dies.disconnect(_on_enemy_dies)
		TriggerType.ON_ATTACK:
			if Global.enemy_attacks_player.is_connected(_on_enemy_attacks):
				Global.enemy_attacks_player.disconnect(_on_enemy_attacks)
		TriggerType.ON_ADVANCE:
			if Global.enemy_advanced.is_connected(_on_enemy_advanced):
				Global.enemy_advanced.disconnect(_on_enemy_advanced)
			


# ─────────────────────────────────────────────────────────────────────────────
#  SIGNAL HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

func _on_enemy_dies(dying_enemy: Enemy) -> void:
	if dying_enemy != entity:
		return
	_fire()
	_disconnect_trigger()


func _on_enemy_attacks(attacker: Enemy, _damage: int) -> void:
	if attacker != entity:
		return
	_fire()


func _on_enemy_advanced(enemy: Enemy, old_range : int, new_range: int) -> void:
	if enemy != entity:
		return
		
	if fire_every_advance or new_range == trigger_range:
		_fire()
# ─────────────────────────────────────────────────────────────────────────────
#  FIRE
# ─────────────────────────────────────────────────────────────────────────────

func _fire() -> void:
	if not triggered_effect:
		push_warning("TriggeredCondition: no triggered_effect set on %s" % get_condition_name())
		return
	for target in _resolve_targets():
		Global.apply_condition.emit(target, triggered_effect)
	trigger_condition()
	


func _resolve_targets() -> Array:
	# Use entity.range_manager directly — it is always set on Enemy by spawn_enemy().
	# entity.run_manager may not be assigned so we avoid that path entirely.
	var rm = entity.range_manager if entity and entity.get("range_manager") else null

	match target_type:
		TargetType.ATTACK_TARGET:
			# The player — walk up to run_manager via range_manager.
			if rm and rm.run_manager and rm.run_manager.player:
				return [rm.run_manager.player]

		TargetType.ALL_ENEMIES:
			if rm:
				return rm.get_all_enemies()

		TargetType.ALL_OTHER_ENEMIES:
			if rm:
				return rm.get_all_enemies().filter(func(e): return e != entity)

		TargetType.ALL_ENEMIES_AT_RANGE:
			if rm:
				return rm.get_all_enemies().filter(
					func(e): return e.current_range == entity.current_range
				)

	push_warning("TriggeredCondition: could not resolve targets for %s" % get_condition_name())
	return []


func trigger_condition() -> void:
	pass  ## Override in a subclass for extra behaviour beyond triggered_effect.

func get_description_with_values() -> String:
	var trigger_text := ""
	match trigger_type:
		TriggerType.ON_DEATH:
			trigger_text = "On death"
		TriggerType.ON_ATTACK:
			trigger_text = "On attack"
		TriggerType.ON_ADVANCE:
			trigger_text = "On advance" if fire_every_advance else "At range %d" % trigger_range

	var target_text := _get_target_text()
	var effect_text := triggered_effect.get_description_with_values()

	return "%s, %s: %s" % [trigger_text, target_text, effect_text]


func _get_target_text() -> String:
	match target_type:
		TargetType.ATTACK_TARGET: return "the attack target"
		TargetType.ALL_ENEMIES: return "all enemies"
		TargetType.ALL_OTHER_ENEMIES: return "all other enemies"
		TargetType.ALL_ENEMIES_AT_RANGE: return "all enemies at the same range"
	return "the target"
