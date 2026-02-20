@abstract
extends Resource
class_name Action

var player : Character
var card_handler : CardHandler  # Reference to card handler for card targeting

# Targeting options
enum TargetType {
	SINGLE_ENEMY,           # Target one enemy (at any range player chooses)
	ALL_ENEMIES,            # Target all enemies regardless of range
	ALL_ENEMIES_AT_RANGE,   # Target all enemies at a specific range
	X_ENEMIES_UP_TO_RANGE,  # Target X enemies up to max range
	SELF,                   # Target the player character
	CARD_IN_HAND,           # Target a card in hand
	CARD_IN_DISCARD,        # Target a card in discard pile
	CARD_IN_DRAW,           # Target a card in draw pile
	RANDOM_CARD_IN_HAND,    # Automatically target random card in hand
	ALL_CARDS_IN_HAND       # Target all cards in hand
}
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var max_range : int = 0


func requires_player_target() -> bool:
	return target_type in [TargetType.SINGLE_ENEMY, TargetType.X_ENEMIES_UP_TO_RANGE, TargetType.ALL_ENEMIES_AT_RANGE]


func requires_card_target() -> bool:
	return target_type in [TargetType.CARD_IN_HAND, TargetType.CARD_IN_DISCARD, TargetType.CARD_IN_DRAW]


func is_automatic_card_action() -> bool:
	return target_type in [TargetType.RANDOM_CARD_IN_HAND, TargetType.ALL_CARDS_IN_HAND]


func get_num_targets(character: Character) -> int:
	if target_type == TargetType.SINGLE_ENEMY:
		return 1
	
	return 1


func execute(target) -> void:
	push_error("execute() must be implemented in %s" % get_script().resource_path)
	

func get_action_type() -> String:
	return "Action"


func get_description_with_values(character) -> String:
	if not character:
		return ""
	
	return ""


func _get_stat_value(character: Character, stat_type: Stat.STAT) -> int:
	for stat in character.stats:
		if stat.stat_type == stat_type:
			return stat.value
	return 0

# Helper to format formula for display with stat names (not values)
func _format_formula_display(formula: String) -> String:
	var display = formula
	
	display = display.replace("*", " x ")
	display = display.replace("/", " / ")
	display = display.replace("+", " + ")
	display = display.replace("-", " - ")
	return display
