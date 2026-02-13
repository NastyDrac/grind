extends Resource
class_name EventOption


@export var option_text: String = "Continue"


@export_multiline var result_text: String = "You continue on your journey."


@export var gold_reward: int = 0
@export var health_change: int = 0 
@export var cards_to_add: Array[CardData] = []  
@export var cards_to_remove: Array[CardData] = []  

# ==== CARD SELECTION SYSTEM ====
enum CardSelectionType {
	NONE,          
	CHOOSE_REWARD,  
	REMOVE_CARDS,   
	TRANSFORM_CARD 
}

@export_group("Card Selection")
@export var random_selection : bool = true
@export var card_selection_type: CardSelectionType = CardSelectionType.NONE
@export var card_selection_pool: Array[CardData] = []  
@export var cards_to_select: int = 1  
@export var selection_is_optional: bool = false  
@export_multiline var selection_prompt: String = "Choose a card:" 


@export_group("Combat")
@export var triggers_combat: bool = true 
@export var combat_horde: Array[EnemyData] = []  
@export var combat_difficulty_modifier: float = 1.0  
@export var win_con : WinCondition

@export_group("Requirements")
@export var gold_cost: int = 0
@export var required_card: CardData = null  


func can_select(player_gold: int, player_deck: Array[CardData]) -> bool:
	if gold_cost > player_gold:
		return false
	
	
	if required_card != null and not player_deck.has(required_card):
		return false
	
	return true


func get_unavailable_reason(player_gold: int, player_deck: Array[CardData]) -> String:
	if gold_cost > player_gold:
		return "Not enough gold (%d required)" % gold_cost
	
	if required_card != null and not player_deck.has(required_card):
		return "Requires card: %s" % required_card.card_name
	
	return ""
