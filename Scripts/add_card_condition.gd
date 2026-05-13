extends Condition
class_name AddCardCondition

@export var card : CardData

func apply_condition(who, condition: Condition) -> void:
	entity = who
	var run : RunManager = entity.run_manager
	
	run.card_handler.create_card(card)
	
func get_description_with_values() -> String:
	return "Add " + card.card_name + " to your deck." 
