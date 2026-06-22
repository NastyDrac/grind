extends Condition
class_name ThornsCondition

## Thorns / Retaliate. Two INDEPENDENT values:
##   • damage — how much an attacker takes back per hit (set on the condition).
##   • stacks — DURATION in turns; drops by 1 at the end of each enemy turn and
##     the condition is removed when it hits 0.
##
## Lives on the player; Character.take_hit() calls react_to_attacker() for every
## incoming attack. Depletion is driven by RangeManager.enemies_finished_turn,
## which fires AFTER all enemies have acted, so a freshly-applied stack always
## covers a full enemy turn before it wears off.

## Damage dealt back to each attacker. Independent of duration (stacks).
@export var damage : int = 0

func apply_condition(who, condition: Condition) -> void:
	entity = who

	var existing = _get_existing_thorns(who)
	if existing == null:
		var new_cond : ThornsCondition = condition.duplicate(true)
		new_cond.entity = who
		new_cond.stacks = condition.stacks      # duration in turns
		new_cond.damage = condition.damage      # reflect amount
		who.conditions.append(new_cond)
		new_cond._connect_turn_signal(who)
	else:
		# Re-casting extends the duration and keeps the stronger reflect.
		existing.stacks += condition.stacks
		existing.damage = max(existing.damage, condition.damage)

func _get_existing_thorns(who) -> ThornsCondition:
	for each_condition in who.conditions:
		if each_condition is ThornsCondition:
			return each_condition
	return null

## Called by Character.take_hit() with the attacking enemy. Reflects `damage`
## while the condition is still active.
func react_to_attacker(attacker) -> void:
	if stacks <= 0 or damage <= 0:
		return
	if not (attacker and is_instance_valid(attacker)):
		return
	# Reflect with NO source: a sourceless hit doesn't trigger the recipient's
	# own react_to_attacker, so thorns-on-player and thorns-on-enemy can't loop.
	# take_hit now exists on both entities; take_damgage is a legacy fallback.
	if attacker.has_method("take_hit"):
		attacker.take_hit(null, damage)
	elif attacker.has_method("take_damgage"):
		attacker.take_damgage(damage)

## End of each enemy turn: burn one turn of duration; remove at zero.
func _on_turn_passed() -> void:
	stacks -= 1
	if stacks <= 0:
		remove_condition(entity)

func _connect_turn_signal(who) -> void:
	var rm = who.get_tree().get_first_node_in_group("range_manager")
	if rm and rm.has_signal("enemies_finished_turn") \
			and not rm.enemies_finished_turn.is_connected(_on_turn_passed):
		rm.enemies_finished_turn.connect(_on_turn_passed)

func _disconnect_turn_signal() -> void:
	if not entity or not is_instance_valid(entity):
		return
	var rm = entity.get_tree().get_first_node_in_group("range_manager")
	if rm and rm.has_signal("enemies_finished_turn") \
			and rm.enemies_finished_turn.is_connected(_on_turn_passed):
		rm.enemies_finished_turn.disconnect(_on_turn_passed)

## Override base cleanup so we always drop the turn-signal connection too
## (covers both natural expiry and end-of-wave teardown).
func remove_condition(who) -> void:
	_disconnect_turn_signal()
	if who and who.conditions.has(self):
		who.conditions.erase(self)

func get_description_with_values() -> String:
	return "When attacked, deal %d damage to the attacker. Lasts %d turn(s)." % [damage, stacks]
