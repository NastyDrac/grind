extends Condition
class_name HealCondition

## Amount of HP to restore. Driven by stacks so TriggeredCondition
## can set it from the inspector like every other condition.

func apply_condition(who, condition: Condition) -> void:
	entity = who

	var existing = get_existing_condition(who, self)
	if existing == null:
		var new_cond : HealCondition = condition.duplicate(true)
		new_cond.entity = who
		new_cond.stacks = condition.stacks
		who.conditions.append(new_cond)
		new_cond._apply_heal()
	else:
		# Stack on top of an existing heal condition and re-heal the difference.
		var extra := condition.stacks
		existing.stacks += extra
		existing._apply_heal_amount(extra)


func _apply_heal() -> void:
	_apply_heal_amount(stacks)


func _apply_heal_amount(amount: int) -> void:
	if not entity:
		return

	var old_hp : int = entity.current_health
	entity.current_health = min(entity.current_health + amount, entity.data.max_health)
	entity.set_health_bar()

	var actually_healed = entity.current_health - old_hp
	if actually_healed <= 0:
		return  # Already full — skip animation.
	Animations.play_heal(entity)
	remove_condition(self)
func get_description_with_values() -> String:
	return "Heal by %d." % stacks
