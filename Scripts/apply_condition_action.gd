extends Action
class_name ApplyConditionAction

# Condition to apply
@export var condition_resource: Condition

# Number of stacks to apply (using ValueCalculator for dynamic calculation)
@export var stacks_calculator: ValueCalculator

func get_action_type() -> String:
	return "Apply Condition"

func execute(target: Variant) -> void:
	if not player:
		push_error("ApplyConditionAction requires valid player")
		return
	

	var stacks_to_apply = stacks_calculator.calculate(player)
	

	var condition_to_apply = condition_resource.duplicate(true)
	condition_to_apply.stacks = stacks_to_apply
	
	
	Global.apply_condition.emit(target, condition_to_apply)

func get_description_with_values(character: Variant) -> String:
	if not character or not stacks_calculator or not condition_resource:
		return "Apply Condition"
	
	var stacks = stacks_calculator.calculate(character)
	var formula_display = _format_formula_display(stacks_calculator.formula)
	var condition_name = _get_condition_name()
	

	var desc = ""
	
	match target_type:
		TargetType.SINGLE_ENEMY:
			desc = "Apply §%d§ (%s) %s" % [stacks, formula_display, condition_name]
		
		TargetType.ALL_ENEMIES:
			desc = "Apply §%d§ (%s) %s to all enemies" % [stacks, formula_display, condition_name]
		
		TargetType.ALL_ENEMIES_AT_RANGE:
			desc = "Apply §%d§ (%s) %s to all at range" % [stacks, formula_display, condition_name]
		
		TargetType.X_ENEMIES_UP_TO_RANGE:
			desc = "Apply §%d§ (%s) %s to multiple enemies" % [stacks, formula_display, condition_name]
		
		TargetType.SELF:
			desc = "Apply §%d§ (%s) %s to self" % [stacks, formula_display, condition_name]
	
	return desc

func _get_condition_name() -> String:
	if not condition_resource:
		return "Unknown Condition"
	
	return condition_resource.get_condition_name()
