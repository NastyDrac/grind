extends EventEffect
class_name EffectAddThingy

## Grants [count] relics (thingies). Normally the single [thingy]; if
## [random_pool] has any entries, each grant rolls a RANDOM one from that pool
## instead (re-rolled per grant, so multiples can differ), keeping the reward
## varied run to run. Random picks use the run's seeded RNG, so a given seed
## still replays the same outcome.
@export var thingy : Condition
## If non-empty, grant a random Condition from this list instead of [thingy].
## Fill it with the positive relics you want this event to be able to roll.
@export var random_pool : Array[Condition] = []
## How many relics to grant.
@export var count : int = 1


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	for i in maxi(1, count):
		var chosen : Condition = thingy
		if not random_pool.is_empty():
			chosen = random_pool[_roll_index(run_manager, random_pool.size())]

		if not chosen:
			push_error("EffectAddThingy: no thingy assigned (neither single nor pool).")
		else:
			run_manager.add_thingy_condition(chosen)
	done.call()


## Random index via the seeded run RNG (falls back to global randi only if the
## run somehow has no rng yet).
func _roll_index(run_manager: RunManager, count_in: int) -> int:
	if run_manager and run_manager.rng:
		return run_manager.rng.randi_range(0, count_in - 1)
	return randi() % count_in


func get_description(run : RunManager) -> String:
	var n := maxi(1, count)
	if not random_pool.is_empty():
		return "Get %d random relics. " % n if n > 1 else "Get a random relic. "
	if thingy:
		if n > 1:
			return "Get %d %s. " % [n, thingy.condition_name]
		return "Get " + thingy.condition_name + ". "
	return ""
