extends EventEffect
class_name EffectCardDraft

## Triggers the standard card-draft screen [count] times in a row.
## Hides the parent EventScene while any draft is open, then restores it once the
## last one resolves.
@export var count : int = 1


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	parent.visible = false
	_run_draft(run_manager, parent, maxi(1, count), done)


## One draft, then recurse (by name) for the next. Restores the parent and calls
## done when the count is exhausted or a draft fails to open.
func _run_draft(run_manager: RunManager, parent: Node, left: int, done: Callable) -> void:
	if left <= 0:
		parent.visible = true
		done.call()
		return

	run_manager.create_draft_screen()

	var draft := run_manager.current_draft_screen
	if draft == null:
		push_warning("EffectCardDraft: create_draft_screen produced no screen.")
		parent.visible = true
		done.call()
		return

	draft.draft_completed.connect(func() -> void:
		_run_draft(run_manager, parent, left - 1, done)
	, CONNECT_ONE_SHOT)

func get_description(run : RunManager) -> String:
	if count <= 1:
		return "Choose a card to add to your deck."
	return "Choose %d cards to add to your deck." % count
