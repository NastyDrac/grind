extends ThingyCondition
class_name TimedThingy
## Base for relics (good or bad) that last a limited number of combats.
## Set duration_combats = 0 for a permanent effect; any positive number makes
## the relic remove itself after that many combats.
##
## Subclasses override _on_combat_start() / _on_combat_end() for their effect.
## State lives on the persistent special_effects instance (same pattern as
## ScrapCollector), so the countdown carries across waves.

## How many combats this lasts. 0 = permanent.
@export var duration_combats: int = 0

## Counts down from duration_combats. -1 means "not yet initialised".
var combats_remaining: int = -1


func setup(who, rm = null) -> void:
	entity = who
	range_manager = rm
	if combats_remaining == -1:
		combats_remaining = duration_combats
	_on_combat_start()


func teardown() -> void:
	_on_combat_end()
	if duration_combats > 0:
		combats_remaining -= 1
		if combats_remaining <= 0:
			_expire()
	range_manager = null


## Pull self out of the run's special_effects so it stops applying next combat.
func _expire() -> void:
	if entity and entity.run_manager:
		entity.run_manager.character.special_effects.erase(self)


## Human-readable duration, e.g. "2 combats" or "permanent".
func _duration_text() -> String:
	if duration_combats <= 0:
		return "permanent"
	return "%d combat%s" % [duration_combats, "" if duration_combats == 1 else "s"]


# --- override in subclasses -------------------------------------------------
func _on_combat_start() -> void:
	pass

func _on_combat_end() -> void:
	pass
