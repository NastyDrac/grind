extends CanvasLayer
class_name Shop

# ─── Rarity price tables ──────────────────────────────────────────────────────
# 0 = Common  1 = Uncommon  2 = Rare
const CARD_PRICES   : Array[int] = [40,  75,  130]
const THINGY_PRICES : Array[int] = [60, 110,  200]
const REMOVE_COST   : int        = 75

# ─── Layout exports ───────────────────────────────────────────────────────────
# Assign these in the Inspector after building your shop scene.
@export var card_slots   : int = 3
@export var thingy_slots : int = 2

@export var gold_label           : Label
@export var leave_button         : Button
@export var card_container       : HBoxContainer
@export var thingy_container     : HBoxContainer
@export var remove_card_button   : Button
@export var remove_overlay       : Panel
@export var deck_card_container  : HFlowContainer
@export var cancel_remove_button : Button

# ─── State ────────────────────────────────────────────────────────────────────
var run : RunManager
var card_scene := preload("res://Scenes/draftable_card.tscn")

signal shop_closed

# ─── Init ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 1
	leave_button.pressed.connect(_on_leave_pressed)
	remove_card_button.pressed.connect(_on_remove_card_pressed)
	cancel_remove_button.pressed.connect(_on_cancel_remove_pressed)
	remove_overlay.visible = false

# ─── Public entry point ───────────────────────────────────────────────────────

func display_shop(run_manager: RunManager) -> void:
	run = run_manager
	_refresh_gold_label()
	_populate_cards()
	_populate_thingies()
	_refresh_remove_button()

# ─── Cards ────────────────────────────────────────────────────────────────────

func _populate_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()

	var offered_card_paths : Array[String] = []

	for _i in range(card_slots):
		var card_data : CardData = run.get_random_card_data(offered_card_paths)
		if not card_data:
			continue
		if card_data.resource_path != "":
			offered_card_paths.append(card_data.resource_path)

		var rarity : int = card_data.get("rarity") if card_data.get("rarity") != null else 0
		var price  := _card_price(rarity)

		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER

		var card : DraftableCard = card_scene.instantiate()
		slot.add_child(card)

		var rarity_lbl := Label.new()
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.text = _rarity_label(rarity)
		rarity_lbl.add_theme_color_override("font_color", _rarity_color(rarity))
		slot.add_child(rarity_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy  (%d Gold)" % price
		slot.add_child(buy_btn)

		card_container.add_child(slot)
		card.set_data(card_data)
		card.current_mode = card.Mode.DISPLAY_ONLY

		buy_btn.pressed.connect(_on_buy_card.bind(card_data, price, buy_btn))

func _on_buy_card(card_data: CardData, price: int, btn: Button) -> void:
	if run.character.gold < price:
		_flash_button(btn, "Need %d Gold!" % price)
		return
	run.character.gold -= price
	run.deck.append(card_data.duplicate(true))
	btn.text = "Purchased!"
	btn.disabled = true
	_refresh_gold_label()
	_refresh_remove_button()

# ─── Thingies ─────────────────────────────────────────────────────────────────

func _populate_thingies() -> void:
	for child in thingy_container.get_children():
		child.queue_free()

	# Seed exclusions with everything the player already owns.
	var excluded_thingy_paths : Array[String] = []
	for effect in run.character.special_effects:
		if effect.resource_path != "":
			excluded_thingy_paths.append(effect.resource_path)

	for _i in range(thingy_slots):
		var condition : ThingyCondition = run.get_random_thingy_condition(excluded_thingy_paths)
		if not condition:
			continue
		# Exclude this thingy from subsequent slots in the same shop visit.
		if condition.resource_path != "":
			excluded_thingy_paths.append(condition.resource_path)

		var rarity : int = condition.rarity
		var price  := _thingy_price(rarity)

		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER

		# ConditionIcon gives us the tooltip on mouse-over for free.
		var icon := ConditionIcon.new()
		icon.set_condition(condition)
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = condition.get_condition_name()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_lbl)

		var rarity_lbl := Label.new()
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.text = _rarity_label(rarity)
		rarity_lbl.add_theme_color_override("font_color", _rarity_color(rarity))
		slot.add_child(rarity_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy  (%d Gold)" % price
		buy_btn.pressed.connect(_on_buy_thingy.bind(condition, price, buy_btn))
		slot.add_child(buy_btn)

		thingy_container.add_child(slot)

func _on_buy_thingy(condition: ThingyCondition, price: int, btn: Button) -> void:
	if run.character.gold < price:
		_flash_button(btn, "Need %d Gold!" % price)
		return
	run.character.gold -= price
	run.add_thingy_condition(condition)
	btn.text = "Purchased!"
	btn.disabled = true
	_refresh_gold_label()

# ─── Remove card ──────────────────────────────────────────────────────────────

func _on_remove_card_pressed() -> void:
	if run.character.gold < REMOVE_COST:
		_flash_button(remove_card_button, "Need %d Gold!" % REMOVE_COST)
		return
	remove_overlay.visible = true
	_populate_deck_for_removal()

func _populate_deck_for_removal() -> void:
	for child in deck_card_container.get_children():
		child.queue_free()

	if run.deck.is_empty():
		var lbl := Label.new()
		lbl.text = "Your deck is empty."
		deck_card_container.add_child(lbl)
		return

	for card_data in run.deck:
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER

		var card : DraftableCard = card_scene.instantiate()
		slot.add_child(card)

		var rarity : int = card_data.get("rarity") if card_data.get("rarity") != null else 0
		var rarity_lbl := Label.new()
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.text = _rarity_label(rarity)
		rarity_lbl.add_theme_color_override("font_color", _rarity_color(rarity))
		slot.add_child(rarity_lbl)

		var remove_btn := Button.new()
		remove_btn.text = "Remove  (-%d Gold)" % REMOVE_COST
		remove_btn.pressed.connect(_on_remove_card_selected.bind(card_data))
		slot.add_child(remove_btn)

		deck_card_container.add_child(slot)
		card.set_data(card_data)
		card.current_mode = card.Mode.DISPLAY_ONLY

func _on_remove_card_selected(card_data: CardData) -> void:
	run.character.gold -= REMOVE_COST
	run.deck.erase(card_data)
	_refresh_gold_label()
	_refresh_remove_button()
	remove_overlay.visible = false

func _on_cancel_remove_pressed() -> void:
	remove_overlay.visible = false

# ─── Leave ────────────────────────────────────────────────────────────────────

func _on_leave_pressed() -> void:
	if run:
		run.close_shop()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _refresh_gold_label() -> void:
	if run and run.character:
		gold_label.text = "Gold: %d" % run.character.gold
		if run.ui_bar:
			run.ui_bar.set_gold()

func _refresh_remove_button() -> void:
	remove_card_button.text = "Remove a Card  (%d Gold)" % REMOVE_COST
	remove_card_button.disabled = (run != null and run.character.gold < REMOVE_COST)

func _card_price(rarity: int) -> int:
	return CARD_PRICES[clampi(rarity, 0, CARD_PRICES.size() - 1)]

func _thingy_price(rarity: int) -> int:
	return THINGY_PRICES[clampi(rarity, 0, THINGY_PRICES.size() - 1)]

func _rarity_label(rarity: int) -> String:
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		_: return "???"

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.75, 0.75, 0.75)
		1: return Color(0.30, 0.80, 0.30)
		2: return Color(0.50, 0.30, 1.00)
		_: return Color.WHITE

func _flash_button(btn: Button, message: String) -> void:
	var original     := btn.text
	var was_disabled := btn.disabled
	btn.text     = message
	btn.disabled = true
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(btn):
		btn.text     = original
		btn.disabled = was_disabled
