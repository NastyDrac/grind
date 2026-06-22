extends Condition
class_name Burning

var decrement := 1
const ICON := preload("res://Art/Icons/BurningIcon.png")
func apply_condition(who, condition: Condition):
	entity = who
	show_stacks = true
	var existing_burning = _get_existing_burning(who)

	if existing_burning == null:
		var new_burning = condition.duplicate(true)
		new_burning.entity = who
		new_burning.stacks = condition.stacks
		who.conditions.append(new_burning)

		Global.time_passed.connect(new_burning.trigger_condition)
	else:
		existing_burning.stacks += condition.stacks

func _get_existing_burning(who) -> Burning:
	for each_condition in who.conditions:
		if each_condition is Burning:
			return each_condition
	return null

func trigger_condition():
	if not entity:
		return
	if stacks > 0:
		# Sourceless damage-over-time: take_hit exists on both the player and
		# enemies, and the null source means burning never procs thorns and can't
		# recurse. (Attacks pass a real source; DoTs and reflections pass null.)
		entity.take_hit(null, stacks)
		stacks -= decrement
	if stacks <= 0:
		if Global.time_passed.is_connected(trigger_condition):
			Global.time_passed.disconnect(trigger_condition)
		remove_condition(entity)
		entity = null

func get_description_with_values() -> String:
	return "Take damage equal to stacks each turn, losing %d stack per turn until it runs out." % decrement
