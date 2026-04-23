extends TriggeredCondition
class_name Trumpeteer

## Trumpeteer generates noise equal to [stacks] whenever its trigger fires.
## The trigger type (ON_DEATH, ON_ATTACK, ON_ADVANCE) is configured in the inspector.
##
## Noise resolution depends on the RangeManager's current spawn_mode:
##   IMMEDIATE / ENERGY_BANKED / TIERED  → spawns [stacks] enemies from the enemy pool
##   METER / MIDDLE_GROUND               → adds [stacks] to the noise meter


## Override _fire() entirely — Trumpeteer has no triggered_effect and does not
## apply a condition to targets.  The base implementation returns early (with a
## warning) when triggered_effect is null, which would silently swallow the
## trigger, so we skip it and go straight to trigger_condition().
func _fire() -> void:
	trigger_condition()


func trigger_condition() -> void:
	var rm: RangeManager = entity.range_manager if entity and entity.get("range_manager") else null
	if rm == null:
		push_warning("Trumpeteer: no RangeManager found on %s" % str(entity))
		return

	match rm.spawn_mode:
		RangeManager.SpawnMode.IMMEDIATE, \
		RangeManager.SpawnMode.ENERGY_BANKED, \
		RangeManager.SpawnMode.TIERED:
			# Noise manifests as immediate enemy spawns — one per stack.
			if rm.enemy_pool.is_empty():
				push_warning("Trumpeteer: enemy pool is empty, cannot spawn.")
				return
			for i in stacks:
				rm.spawn_enemy(rm.enemy_pool.pick_random(), 5)

		RangeManager.SpawnMode.METER, \
		RangeManager.SpawnMode.MIDDLE_GROUND:
			# Noise fills the meter directly.
			rm.noise_meter += stacks
			


func get_description_with_values() -> String:
	var trigger_text := ""
	match trigger_type:
		TriggerType.ON_DEATH:
			trigger_text = "On death"
		TriggerType.ON_ATTACK:
			trigger_text = "On attack"
		TriggerType.ON_ADVANCE:
			trigger_text = "On advance" if fire_every_advance else "At range %d" % trigger_range

	return "%s: generates %d noise." % [
	trigger_text,
	stacks
	]
