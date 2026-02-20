extends Condition
class_name ScrapCollector

## How many scrap the Engineer must collect before crafting a turret card.
@export var scrap_threshold: int = 5

## Optional: assign a pre-built CardData asset in the editor.
## If left empty the condition will build a default one at runtime.
@export var turret_card_data: CardData

## Optional: override turret damage from here so it shows up on the condition.
@export var turret_damage: ValueCalculator


# ─────────────────────────────────────────────
# APPLY
# ─────────────────────────────────────────────

func apply_condition(who, condition: Condition) -> void:
	entity = who

	for existing in who.conditions:
		if existing is ScrapCollector:
			return

	var new_condition: ScrapCollector = condition.duplicate(true)
	new_condition.entity = who
	new_condition.stacks = 0
	new_condition.show_stacks = true  # display scrap count on the icon

	who.conditions.append(new_condition)

	if not Global.item_picked_up.is_connected(new_condition._on_item_picked_up):
		Global.item_picked_up.connect(new_condition._on_item_picked_up)

	if not Global.time_passed.is_connected(new_condition._on_time_passed):
		Global.time_passed.connect(new_condition._on_time_passed)


# ─────────────────────────────────────────────
# SCRAP COLLECTION — just count, never craft here
# ─────────────────────────────────────────────

func _on_item_picked_up(item: Item) -> void:
	if item.item.item_name != "Scrap":
		return
	stacks += 1


# ─────────────────────────────────────────────
# TIME STEP — check threshold and craft if ready
# ─────────────────────────────────────────────

func _on_time_passed() -> void:
	if stacks < scrap_threshold:
		return

	stacks = 0
	_craft_turret_card()


# ─────────────────────────────────────────────
# CARD CRAFTING
# ─────────────────────────────────────────────

func _turret_card_in_hand(card_handler: CardHandler) -> bool:
	for card in card_handler.cards_in_hand:
		if card.data and card.data.card_name == "Deploy Turret":
			return true
	return false


func _craft_turret_card() -> void:
	if not entity:
		return

	var run_manager: RunManager = entity.run_manager
	if not run_manager or not run_manager.card_handler:
		push_warning("ScrapCollector: no card_handler found on run_manager.")
		return

	var card_handler: CardHandler = run_manager.card_handler

	if _turret_card_in_hand(card_handler):
		return

	var data: CardData = turret_card_data if turret_card_data else _build_turret_card_data()

	var new_card = load("res://Scenes/card.tscn").instantiate()
	card_handler.draw_pile.add_child(new_card)
	new_card.set_data(data)
	new_card.card_hovered.connect(card_handler.hover_card.bind())
	await card_handler.add_card_to_hand(new_card)


func _build_turret_card_data() -> CardData:
	var data := CardData.new()
	data.card_name = "Deploy Turret"
	data.exhaust = true

	var action := DeployTurretAction.new()
	action.target_type = Action.TargetType.SINGLE_ENEMY
	action.max_range = 5
	action.damage = turret_damage

	data.actions.append(action)

	return data


# ─────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────

func remove_condition(who) -> void:
	if Global.item_picked_up.is_connected(_on_item_picked_up):
		Global.item_picked_up.disconnect(_on_item_picked_up)
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
	who.conditions.erase(self)
