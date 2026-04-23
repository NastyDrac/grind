extends EventEffect
class_name EffectAddThingy

@export var thingy : Condition
func execute(_run_manager: RunManager, _parent: Node, done: Callable) -> void:
	if not thingy:
		push_error("No thingy assigned")
	else:
		_run_manager.add_thingy_condition(thingy)
	
	done.call()

func get_description(run : RunManager) -> String:
	return "Get " + thingy.condition_name
