extends Resource
class_name EventOption


@export var option_text: String = "Continue"
@export_multiline var result_text: String = "You continue on your journey."

## Effects applied in order when the player chooses this option.
## Add any number of EventEffect subclass instances here:
##   EffectCostHP, EffectCostGold, EffectRemoveCard, EffectAddCard,
##   EffectCardDraft, EffectAddAction, EffectCardFlag
@export var effects: Array[EventEffect] = []


@export_group("Combat")
@export var triggers_combat: bool = false
@export var combat_horde: Array[EnemyData] = []
@export var combat_difficulty_modifier: float = 1.0
@export var win_con: WinCondition


@export_group("Requirements")
## Gold the player must have to pick this option. Deducted immediately on selection.
@export var gold_cost: int = 0
## A card the player must own to pick this option (not consumed).
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
