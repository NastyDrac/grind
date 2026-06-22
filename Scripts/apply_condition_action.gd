extends Action
class_name ApplyConditionAction

# Condition to apply
@export var condition_resource: Condition

## Optional. Stacking / keyword conditions (e.g. Burning) use this to compute
## their stack count. Bespoke conditions (is_keyword = false) usually don't stack
## and can leave this null — the action then falls back to the condition
## resource's own default stacks, so no dummy calculator is required.
@export var stacks_calculator: ValueCalculator


func get_action_type() -> String:
	return "Apply Condition"


## Stacks to apply: the calculator's value if one is set, otherwise the condition
## resource's own default stacks. This is what lets non-stacking conditions skip
## the calculator entirely.
func _resolved_stacks(character) -> int:
	if stacks_calculator and character:
		return stacks_calculator.calculate(character)
	if condition_resource:
		return condition_resource.stacks
	return 0


func execute(target: Variant) -> void:
	if not player:
		push_error("ApplyConditionAction requires valid player")
		return
	if not condition_resource:
		push_error("ApplyConditionAction: no condition_resource set")
		return

	var condition_to_apply = condition_resource.duplicate(true)
	condition_to_apply.stacks = _resolved_stacks(player)

	Global.apply_condition.emit(target, condition_to_apply)


func _get_condition_name() -> String:
	if not condition_resource:
		return "Unknown Condition"
	return condition_resource.get_condition_name()


# ============================================================================
# CARD BODY / TOOLTIP SPLIT  (honors Condition.is_keyword)
# ============================================================================

## Keyword conditions (Burning, etc.) read as "Apply X <Name>" on the card and
## are explained in the tooltip. Non-keyword conditions are bespoke effects whose
## OWN description IS the card text — shown inline, no stacks_calculator needed.
func get_card_text(character) -> String:
	if not condition_resource:
		return "Apply Condition"

	# Bespoke effect: the condition describes itself.
	if not condition_resource.is_keyword:
		var temp = condition_resource.duplicate(true)
		temp.stacks = _resolved_stacks(character)
		return temp.get_description_with_values()

	# Keyword: "Apply X <Name>".
	var stacks = _resolved_stacks(character)
	if stacks_calculator:
		return "Apply %s %s%s" % [_cv(stacks, stacks_calculator.formula), condition_resource.get_condition_name(), _target_suffix()]
	return "Apply %d %s%s" % [stacks, condition_resource.get_condition_name(), _target_suffix()]


func get_description_with_values(character: Variant) -> String:
	if not condition_resource:
		return "Apply Condition"

	# Bespoke effect: describe itself (also used by the shop / longer tooltips).
	if not condition_resource.is_keyword:
		var temp = condition_resource.duplicate(true)
		temp.stacks = _resolved_stacks(character)
		return temp.get_description_with_values()

	var stacks = _resolved_stacks(character)
	var condition_name = _get_condition_name()
	var stacks_str = ("§%d§ (%s)" % [stacks, _format_formula_display(stacks_calculator.formula)]) if stacks_calculator else ("§%d§" % stacks)

	match target_type:
		TargetType.SINGLE_ENEMY:
			return "Apply %s %s" % [stacks_str, condition_name]
		TargetType.ALL_ENEMIES:
			return "Apply %s %s to all enemies" % [stacks_str, condition_name]
		TargetType.ALL_ENEMIES_AT_RANGE:
			return "Apply %s %s to all at range" % [stacks_str, condition_name]
		TargetType.X_ENEMIES_UP_TO_RANGE:
			return "Apply %s %s to multiple enemies" % [stacks_str, condition_name]
		TargetType.SELF:
			return "Apply %s %s to self" % [stacks_str, condition_name]

	return "Apply %s %s" % [stacks_str, condition_name]


func get_tooltip_text(character) -> String:
	if not condition_resource:
		return ""
	var lines : Array[String] = []

	# Keyword conditions explain themselves in the tooltip. Bespoke conditions
	# already show their full text in the card body, so they add no tooltip line.
	if condition_resource.is_keyword:
		var explain = condition_resource.get_description_with_values()
		if explain != "":
			lines.append("%s — %s" % [condition_resource.get_condition_name(), explain])

	# Show the stacks breakdown only when a formula is actually driving it.
	if stacks_calculator and character:
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
