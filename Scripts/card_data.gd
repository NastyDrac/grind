extends Resource
class_name CardData

@export var card_name: String = "Card"
@export var card_cost: int = 1
var card_description: String = ""
@export var card_image: Texture2D
enum RARITY {Common, Uncommon, Rare}
@export var rarity : RARITY
# Multiple actions per card
@export var actions: Array[Action] = []
@export var exhaust : bool
@export var fickle : bool
# Get the full card description with calculated values
func get_description_with_values(character_data: Character) -> String:
	var desc = card_description
	
	# If description has placeholders, replace them with action values
	for i in actions.size():
		var action = actions[i]
		if action:
			var value = action.calculate_value(character_data)
			# Support {0}, {1}, {2} for multiple action values
			desc = desc.replace("{%d}" % i, str(value))
	
	return desc

# Execute all actions on this card
func execute_card(character_data: Character, targets: Array):
	pass

func _filter_targets_by_range(targets: Array, range: int) -> Array:
	if range == -1:
		return targets
	
	var filtered = []
	for target in targets:
		if target.has_method("get_current_range") and target.get_current_range() == range:
			filtered.append(target)
	
	return filtered

func _select_random_per_range(targets: Array, max_range: int) -> Array:
	# Group enemies by range
	var enemies_by_range: Dictionary = {}
	
	for target in targets:
		if target.has_method("get_current_range"):
			var range = target.get_current_range()
			if range <= max_range:
				if not enemies_by_range.has(range):
					enemies_by_range[range] = []
				enemies_by_range[range].append(target)
	
	# Pick one random enemy from each range
	var selected = []
	for range in range(1, max_range + 1):
		if enemies_by_range.has(range) and enemies_by_range[range].size() > 0:
			selected.append(enemies_by_range[range].pick_random())
	
	return selected
