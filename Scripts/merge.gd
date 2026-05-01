extends TriggeredCondition
class_name MergeEffect

const GROW_AMOUNT  := 0.15
const MAX_SCALE    := Vector2(1.0, 1.0)


func _fire() -> void:
	var range_manager : RangeManager = entity.range_manager
	var current_range = entity.get_current_range()

	for enemy : Enemy in range_manager.get_enemies_at_range(current_range):
		if enemy == entity:
			continue

		var has_merge := false
		for con : Condition in enemy.conditions:
			if con.get_condition_name() == get_condition_name():
				has_merge = true
				break

		if not has_merge:
			continue

		# Pull it from game logic immediately so it can't act during the animation.
		range_manager.remove_enemy(enemy)
		# Null the range_manager so enemy._process stops lerping it to its old position,
		# which would fight the slide animation.
		enemy.range_manager = null
		
		# Combine stats now so the health bar updates right away.
		entity.data.damage     += enemy.data.damage
		entity.max_health      += enemy.max_health
		entity.data.max_health  = entity.max_health
		entity.data.min_health  = entity.max_health
		entity.current_health  += enemy.current_health
		entity.set_health_bar()

		stacks += 1
		_animate_merge(enemy)

		# One merge per trigger — next advance handles any further candidates.
		break


func _animate_merge(absorbed: Enemy) -> void:
	const TRAVEL_TIME  := 0.25   # how long the absorbed slime takes to slide over
	const INHALE_TIME  := 0.08   # survivor squishes inward just before impact
	const POP_TIME     := 0.28   # survivor springs out to its new larger scale
	const INHALE_SCALE := 0.82   # how much the survivor pulls inward (fraction of current scale)

	var current_scale = entity.sprite.scale
	var target_scale  = (current_scale + Vector2(GROW_AMOUNT, GROW_AMOUNT)).min(MAX_SCALE)
	var inhale_scale  = current_scale * INHALE_SCALE

	# --- Absorbed slime: slide toward the survivor and fade out ---
	# Both tweeners share a tween created from the survivor (entity), so they are
	# not tied to the absorbed node's lifetime.
	var slide_tween = entity.create_tween()
	slide_tween.tween_property(entity, "position", absorbed.position, TRAVEL_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	slide_tween.parallel().tween_property(absorbed, "modulate:a", 0.0, TRAVEL_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Free the absorbed enemy the moment it arrives.
	slide_tween.tween_callback(absorbed.queue_free)

	# --- Survivor: inhale as the absorbed slime approaches, then pop to new scale ---
	var grow_tween = entity.create_tween()
	# Wait until just before impact, then pull inward...
	grow_tween.tween_interval(TRAVEL_TIME - INHALE_TIME)
	grow_tween.tween_property(entity.sprite, "scale", inhale_scale, INHALE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	# ...then spring out to the permanently larger scale.
	grow_tween.tween_property(entity.sprite, "scale", target_scale, POP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	Global.enemy_advanced.emit(entity, entity.current_range, entity.current_range)

func get_description_with_values() -> String:
	return "This enemy will merge with others at the same range."
