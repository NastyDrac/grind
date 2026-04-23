extends Resource
class_name EventEffect

var run_manager : RunManager
## Base class for all event option effects.
##
## Each effect implements execute(), which receives the RunManager, the parent
## Node to attach any UI to (always the EventScene), and a Callable to invoke
## when the effect is finished so the queue can advance.
##
## Instant effects apply their change and call done immediately.
## Async effects (card selection, draft) open their own UI, wait for input,
## apply, then call done.

func execute(_run_manager: RunManager, _parent: Node, done: Callable) -> void:
	run_manager = _run_manager
	done.call()

func get_description(run : RunManager) -> String:
	return ""
