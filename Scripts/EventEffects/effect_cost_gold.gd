extends EventEffect
class_name EffectCostGold

## Adjusts the player's gold by [amount].
## Positive values grant gold; negative values cost gold.
@export var amount: int = 10


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	print("[CostGold] before=", run_manager.character.gold, " amount=", amount)
	run_manager.character.gold -= amount
	print("[CostGold] after=", run_manager.character.gold)
	run_manager.ui_bar.set_gold()
	done.call()

func get_description(run : RunManager) -> String:
	# Matches execute(): positive grants gold, negative costs it.
	if amount > 0:
		return "Lose %s gold." % amount
	elif amount < 0:
		return "Gain %s gold." % abs(amount)
	else:
		return ""
