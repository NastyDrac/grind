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


# ============================================================================
# CARD BODY / TOOLTIP SPLIT  (honors Condition.is_keyword)
# ============================================================================

## Keyword conditions (Burning, etc.) read as "Apply X <Name>" on the card and
## get explained in the tooltip. Non-keyword conditions are bespoke effects whose
## full description IS the card text (e.g. "Deal X damage to a random enemy when
## a card is exhausted").
func get_card_text(character) -> String:
	if not character or not stacks_calculator or not condition_resource:
		return "Apply Condition"
	var stacks = stacks_calculator.calculate(character)

	if condition_resource.is_keyword:
		return "Apply §%d§ %s%s" % [stacks, condition_resource.get_condition_name(), _target_suffix()]

	# Bespoke effect: show its own description, with the value baked in.
	var temp = condition_resource.duplicate(true)
	temp.stacks = stacks
	return temp.get_description_with_values()


func get_tooltip_text(character) -> String:
	if not character or not stacks_calculator or not condition_resource:
		return ""
	var lines : Array[String] = []

	# Keyword conditions explain themselves in the tooltip.
	if condition_resource.is_keyword:
		var explain = condition_resource.get_description_with_values()
		if explain != "":
			lines.append("%s — %s" % [condition_resource.get_condition_name(), explain])

	# Either kind shows the stacks formula if it isn't a plain number.
	var stacks_line = _formula_breakdown("stacks", stacks_calculator.calculate(character), stacks_calculator.formula)
	if stacks_line != "":
		lines.append(stacks_line)

	return "\n".join(lines)


func _target_suffix() -> String:
	match target_type:
		TargetType.ALL_ENEMIES:
			return " to all enemies"
		TargetType.ALL_ENEMIES_AT_RANGE:
			return " to all at range"
		TargetType.X_ENEMIES_UP_TO_RANGE:
			return " to multiple enemies"
		TargetType.SELF:
			return " to self"
		_:
			return ""
