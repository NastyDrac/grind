extends Action
class_name BlockAction

@export var block_calculator : ValueCalculator

func get_action_type() -> String:
	return "Block"

func execute(target: Variant) -> void:
	if not player:
		push_error("BlockAction requires valid player")
		return
	player.gain_block(block_calculator.calculate(player))

func get_description_with_values(character: Variant) -> String:
	if not character or not block_calculator:
		return "Block"
	
	var block_amount = block_calculator.calculate(character)
	var formula_display = _format_formula_display(block_calculator.formula)
	
	return "Gain §%d§ (%s) Block" % [block_amount, formula_display]
