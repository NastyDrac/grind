extends EventEffect
class_name EffectCostHP

## Reduces (or restores) the player's current HP by [amount].
## Positive values deal damage; negative values heal.
@export var amount: int = 5


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	run_manager.character.current_health -= amount
	run_manager.character.current_health = clamp(
		run_manager.character.current_health,
		0,
		run_manager.character.max_health.calculate(run_manager.player)
	)
	run_manager.ui_bar.set_health()
	done.call()

func get_description(run : RunManager) -> String:
	if amount > 0:
		return "Lose %s health." %amount
	elif amount < 0:
		return "Gain %s health." %abs(amount)
	else:
		return ""
