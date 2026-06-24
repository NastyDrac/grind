extends EventEffect
class_name EffectAddThingy

## Grants [count] relics (thingies).
##  - random_thingy = false: grants the specific [thingy].
##  - random_thingy = true:  ignores [thingy] and pulls random relics straight
##    from the full pool (res://Thingys/) via the RunManager — no hand-filled
##    list to maintain. Uses get_unique_thingy_condition so you won't be handed a
##    relic you already own, and grants within one event stay distinct.
@export var thingy : Condition
## Pull random relics from the whole game pool instead of granting [thingy].
@export var random_thingy : bool = false
## How many relics to grant.
@export var count : int = 1


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	if random_thingy:
		_grant_random(run_manager)
	else:
		for i in maxi(1, count):
			if thingy == null:
				push_error("EffectAddThingy: random_thingy is off but no thingy assigned.")
				break
			run_manager.add_thingy_condition(thingy)
	done.call()


func _grant_random(run_manager: RunManager) -> void:
	# Track what we hand out so a multi-grant event gives different relics.
	var granted : Array[String] = []
	for i in maxi(1, count):
		var chosen : ThingyCondition = run_manager.get_unique_thingy_condition(granted)
		# Pool exhausted relative to owned + already-granted: rather than grant
		# nothing, allow a repeat from the full pool.
		if chosen == null:
			chosen = run_manager.get_random_thingy_condition()
		if chosen == null:
			push_warning("EffectAddThingy: no thingies available in res://Thingys/ to grant.")
			break
		if chosen.resource_path != "":
			granted.append(chosen.resource_path)
		run_manager.add_thingy_condition(chosen)


func get_description(run : RunManager) -> String:
	var n := maxi(1, count)
	if random_thingy:
		return "Get %d random relics. " % n if n > 1 else "Get a random relic. "
	if thingy:
		if n > 1:
			return "Get %d %s. " % [n, thingy.condition_name]
		return "Get " + thingy.condition_name + ". "
	return ""


## Hover tooltip: the granted relic's name and description (or a note for random).
func get_tooltip_text() -> String:
	if random_thingy:
		return "A random relic from the pool."
	if thingy:
		return "%s\n%s" % [thingy.condition_name, thingy.get_description_with_values()]
	return ""
