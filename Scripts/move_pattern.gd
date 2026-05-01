@tool
extends Resource
class_name MovePattern

## Ordered list of steps. The enemy evaluates top-to-bottom and executes the
## first step whose predicate passes. If nothing matches, the enemy falls back
## to its default advance-or-attack behavior.
@export var steps: Array[MoveStep] = []


func get_active_step(enemy: Enemy) -> MoveStep:
	for step in steps:
		if step.evaluate(enemy):
			return step
	return null
