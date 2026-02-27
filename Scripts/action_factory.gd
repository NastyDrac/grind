extends Node
class_name ActionFactory

#Does not currently work

static func create_damage_action(expression: String, target_type = Action.TargetType.SINGLE_ENEMY, description: String = "") -> Action:
	var action = AttackAction.new()
	action.value_expression = expression
	action.target_type = target_type
	action.description = description if description else "Deal {value} damage"
	return action

static func create_heal_action(expression: String, target_type = Action.TargetType.SELF, description: String = "") -> Action:
	return null

static func create_draw_action(expression: String, description: String = "") -> Action:
	return null

static func create_aoe_damage(expression: String, description: String = "") -> Action:
	return null

static func create_ranged_attack(expression: String, range: int, description: String = "") -> Action:
	return null

static func create_spread_attack(expression: String, max_range: int, description: String = "") -> Action:
	return null
