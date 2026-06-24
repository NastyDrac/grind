extends ThingyCondition
class_name LootGoblin

## "Loot Goblin" — everything shiny is worth grabbing. Every item you pick up
## (scrap included) also coughs up gold. Combat-only listener; the gold itself is
## awarded at the run level via the player's RunManager.

## Gold granted per item collected.
@export var gold_per_item : int = 3


func setup(who, rm) -> void:
	super(who, rm)
	if not Global.item_picked_up.is_connected(_on_item_picked_up):
		Global.item_picked_up.connect(_on_item_picked_up)


func teardown() -> void:
	if Global.item_picked_up.is_connected(_on_item_picked_up):
		Global.item_picked_up.disconnect(_on_item_picked_up)
	super()


func _on_item_picked_up(_item) -> void:
	if entity and entity.run_manager:
		entity.run_manager.award_gold(gold_per_item)


func get_description_with_values() -> String:
	return "Whenever you pick up an item, gain %d gold." % gold_per_item
