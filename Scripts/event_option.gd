extends Resource
class_name EventOption

# The text shown on the button/option
@export var option_text: String = "Continue"

# What happens when this option is selected
@export_multiline var result_text: String = "You continue on your journey."

# Rewards/consequences
@export var gold_reward: int = 0
@export var health_change: int = 0  # Positive for healing, negative for damage
@export var cards_to_add: Array[CardData] = []  # Cards added to deck automatically
@export var cards_to_remove: Array[CardData] = []  # Cards removed from deck automatically

# ==== CARD SELECTION SYSTEM ====
enum CardSelectionType {
	NONE,           # No card selection (use cards_to_add/remove directly)
	CHOOSE_REWARD,  # Player chooses cards from a pool (rewards)
	REMOVE_CARDS,   # Player removes cards from their deck (purge)
	TRANSFORM_CARD  # Player upgrades/transforms a card (future use)
}

@export_group("Card Selection")
@export var random_selection : bool = true
@export var card_selection_type: CardSelectionType = CardSelectionType.NONE
@export var card_selection_pool: Array[CardData] = []  # Pool of cards to choose from
@export var cards_to_select: int = 1  # How many cards player must/can select
@export var selection_is_optional: bool = false  # Can player skip selection?
@export_multiline var selection_prompt: String = "Choose a card:"  # Text shown during selection

# Combat parameters
@export_group("Combat")
@export var triggers_combat: bool = true  # Does this option lead to a fight?
@export var combat_horde: Array[EnemyData] = []  # Which zombies appear if combat is triggered
@export var combat_difficulty_modifier: float = 1.0  # Multiplier for enemy count/strength

# Requirements (optional)
@export_group("Requirements")
@export var gold_cost: int = 0
@export var required_card: CardData = null  # Player must have this card to select this option

# Can this option be selected?
func can_select(player_gold: int, player_deck: Array[CardData]) -> bool:
	# Check gold requirement
	if gold_cost > player_gold:
		return false
	
	# Check card requirement
	if required_card != null and not player_deck.has(required_card):
		return false
	
	return true

# Get tooltip text explaining why this option can't be selected
func get_unavailable_reason(player_gold: int, player_deck: Array[CardData]) -> String:
	if gold_cost > player_gold:
		return "Not enough gold (%d required)" % gold_cost
	
	if required_card != null and not player_deck.has(required_card):
		return "Requires card: %s" % required_card.card_name
	
	return ""
