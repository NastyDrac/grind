extends EventEffect
class_name EffectCardDraft

## Triggers the standard card-draft screen.
## Hides the parent EventScene while the draft is open, then restores it.


func execute(run_manager: RunManager, parent: Node, done: Callable) -> void:
	parent.visible = false
	run_manager.create_draft_screen()

	var draft := run_manager.current_draft_screen
	if draft == null:
		push_warning("EffectCardDraft: create_draft_screen produced no screen.")
		parent.visible = true
		done.call()
		return

	draft.draft_completed.connect(func() -> void:
		parent.visible = true
		done.call()
	, CONNECT_ONE_SHOT)

func get_description(run : RunManager) -> String:
	return "Choose a card to add to your deck."
