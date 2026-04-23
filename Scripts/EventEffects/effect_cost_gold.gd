extends EventEffect
class_name EffectCostGold

## Adjusts the player's gold by [amount].
## Positive values grant gold; negative values cost gold.
@export var amount: int = 10


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	run_manager.character.gold += amount
	run_manager.ui_bar.set_gold()
	done.call()

func get_description(run : RunManager) -> String:
	if amount > 0:
		return "Lose %s gold." %amount
	elif amount < 0:
		return "Gain %s gold." %abs(amount)
	else:
		return ""
