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
	
	if not condition_resource:
		push_error("ApplyConditionAction requires a condition_resource")
		return
	
	if not stacks_calculator:
		push_error("ApplyConditionAction requires a stacks_calculator")
		return
	
	# Calculate stacks
	var stacks_to_apply = stacks_calculator.calculate(player)
	
	# Create a copy of the condition with the calculated stacks
	var condition_to_apply = condition_resource.duplicate(true)
	condition_to_apply.stacks = stacks_to_apply
	
	# Apply condition to target (target should be an Enemy)
	if target is Enemy:
		condition_to_apply.apply_condition(target, condition_to_apply)
	else:
		push_warning("ApplyConditionAction can only target Enemy types")

func get_description_with_values(character: Variant) -> String:
	if not character or not stacks_calculator or not condition_resource:
		return "Apply Condition"
	
	var stacks = stacks_calculator.calculate(character)
	var formula_display = _format_formula_display(stacks_calculator.formula)
	var condition_name = _get_condition_name()
	
	# Build description based on targeting
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
