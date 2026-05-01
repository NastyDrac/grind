@tool
extends Resource
class_name MoveStep

enum Predicate {
	ALWAYS,              # Always passes — use as a fallback at the bottom of the list
	HEALTH_BELOW,        # threshold = percentage 0–100
	HEALTH_ABOVE,        # threshold = percentage 0–100
	AT_ATTACK_RANGE,     # current_range <= attack_range
	RANGE_EQUALS,        # threshold = exact range number
	RANGE_BELOW,         # closer than threshold
	RANGE_ABOVE,         # further than threshold
	ALLIES_AT_SAME_RANGE # more than one enemy shares this range
}

enum MoveAction {
	ADVANCE,             # Move toward player by move_speed
	RETREAT,             # Move away from player by move_speed
	HOLD,                # Don't move, don't attack
	ATTACK,              # Attack if in range, otherwise advance
	ATTACK_THEN_RETREAT, # Attack if in range, then retreat (advance if not in range)
	ATTACK_THEN_ADVANCE  # Attack if in range, then advance again (advance if not in range)
}

## The condition that must be true for this step to fire.
@export var predicate: Predicate = Predicate.ALWAYS
## What the enemy does when the predicate passes.
@export var action: MoveAction = MoveAction.ADVANCE
## Numeric threshold used by HEALTH_BELOW/ABOVE (percentage) and RANGE_* (range number).
@export var threshold: float = 0.0


func evaluate(enemy: Enemy) -> bool:
	match predicate:
		Predicate.ALWAYS:
			return true
		Predicate.HEALTH_BELOW:
			return float(enemy.current_health) / float(enemy.max_health) * 100.0 < threshold
		Predicate.HEALTH_ABOVE:
			return float(enemy.current_health) / float(enemy.max_health) * 100.0 > threshold
		Predicate.AT_ATTACK_RANGE:
			return enemy.current_range <= enemy.data.attack_range
		Predicate.RANGE_EQUALS:
			return enemy.current_range == int(threshold)
		Predicate.RANGE_BELOW:
			return enemy.current_range < int(threshold)
		Predicate.RANGE_ABOVE:
			return enemy.current_range > int(threshold)
		Predicate.ALLIES_AT_SAME_RANGE:
			if not enemy.range_manager:
				return false
			return enemy.range_manager.get_enemies_at_range(enemy.current_range).size() > 1
	return false


func get_action_label() -> String:
	match action:
		MoveAction.ADVANCE:           return "Advance"
		MoveAction.RETREAT:           return "Retreat"
		MoveAction.HOLD:              return "Hold"
		MoveAction.ATTACK:            return "Attack"
		MoveAction.ATTACK_THEN_RETREAT: return "Attack & Retreat"
		MoveAction.ATTACK_THEN_ADVANCE: return "Attack & Advance"
	return "?"
