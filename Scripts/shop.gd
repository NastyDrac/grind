extends CanvasLayer
class_name Shop

# ─── Layout ───────────────────────────────────────────────────────────────────
# Adjust UIBAR_HEIGHT to match your UIBar's actual pixel height.
const UIBAR_HEIGHT : float = 50.0
const MARGIN       : float = 40.0

# ─── Rarity price tables ──────────────────────────────────────────────────────
# 0 = Common  1 = Uncommon  2 = Rare
const CARD_PRICES   : Array[int] = [40,  75,  130]
const THINGY_PRICES : Array[int] = [60, 110,  200]
const REMOVE_COST   : int        = 75

const CARD_SLOTS   : int = 3
const THINGY_SLOTS : int = 2

# ─── State ────────────────────────────────────────────────────────────────────
var run : RunManager
var card_scene := preload("res://Scenes/draftable_card.tscn")

# ─── Built nodes ──────────────────────────────────────────────────────────────
var gold_label           : Label
var leave_button         : Button
var card_container       : HBoxContainer
var thingy_container     : HBoxContainer
var remove_card_button   : Button
var remove_vbox          : VBoxContainer
var deck_container       : VBoxContainer   # buttons, one per deck card
var cancel_remove_button : Button

signal shop_closed

# ─── Build the UI ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 1
	_build_ui()

func _build_ui() -> void:
	# ── Backdrop panel ──
	var panel := Panel.new()
	panel.anchor_left   = 0.0
	panel.anchor_top    = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   =  MARGIN
	panel.offset_top    =  UIBAR_HEIGHT
	panel.offset_right  = -MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)

	# ── Root VBox ──
	var root_vbox := VBoxContainer.new()
	root_vbox.anchor_right  = 1.0
	root_vbox.anchor_bottom = 1.0
	root_vbox.offset_left   =  12.0
	root_vbox.offset_top    =  8.0
	root_vbox.offset_right  = -12.0
	root_vbox.offset_bottom = -8.0
	root_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(root_vbox)

	# ── Top bar: title | gold | leave ──
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "El Shoppe"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(title_lbl)

	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(gold_label)

	leave_button = Button.new()
	leave_button.text = "Leave Shop"
	leave_button.pressed.connect(_on_leave_pressed)
	top_bar.add_child(leave_button)

	root_vbox.add_child(HSeparator.new())

	# ── Scroll area: cards + thingies ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_vbox)

	var cards_lbl := Label.new()
	cards_lbl.text = "Cards for Sale"
	cards_lbl.add_theme_font_size_override("font_size", 14)
	scroll_vbox.add_child(cards_lbl)

	card_container = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", 16)
	scroll_vbox.add_child(card_container)

	scroll_vbox.add_child(HSeparator.new())

	var thingies_lbl := Label.new()
	thingies_lbl.text = "Thingies for Sale"
	thingies_lbl.add_theme_font_size_override("font_size", 14)
	scroll_vbox.add_child(thingies_lbl)

	thingy_container = HBoxContainer.new()
	thingy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	thingy_container.add_theme_constant_override("separation", 16)
	scroll_vbox.add_child(thingy_container)

	root_vbox.add_child(HSeparator.new())

	# ── Remove card button — pinned at bottom ──
	remove_card_button = Button.new()
	remove_card_button.pressed.connect(_on_remove_card_pressed)
	root_vbox.add_child(remove_card_button)

	# ── Deck removal overlay — hidden until needed ──
	remove_vbox = VBoxContainer.new()
	remove_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	remove_vbox.visible = false
	root_vbox.add_child(remove_vbox)

	var remove_lbl := Label.new()
	remove_lbl.text = "Select a card to remove from your deck:"
	remove_vbox.add_child(remove_lbl)

	# Scrollable list of card-name buttons — much smaller than full card previews
	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	remove_vbox.add_child(deck_scroll)

	deck_container = VBoxContainer.new()
	deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_container.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(deck_container)

	cancel_remove_button = Button.new()
	cancel_remove_button.text = "Cancel"
	cancel_remove_button.pressed.connect(_on_cancel_remove_pressed)
	remove_vbox.add_child(cancel_remove_button)

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

	for _i in range(CARD_SLOTS):
		var card_data : CardData = run.get_random_card_data()
		if not card_data:
			continue

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

		# Add to tree BEFORE set_data so DraftableCard.is_node_ready() is true
		card_container.add_child(slot)
		card.set_data(card_data)
		card.current_mode = card.Mode.DISPLAY_ONLY

		buy_btn.pressed.connect(_on_buy_card.bind(card_data, price, buy_btn))

func _on_buy_card(card_data: CardData, price: int, btn: Button) -> void:
	if run.character.gold < price:
		_flash_button(btn, "Need %d Gold!" % price)
		return
	run.character.gold -= price
	run.deck.append(card_data)
	btn.text = "Purchased!"
	btn.disabled = true
	_refresh_gold_label()
	_refresh_remove_button()

# ─── Thingies ─────────────────────────────────────────────────────────────────

func _populate_thingies() -> void:
	for child in thingy_container.get_children():
		child.queue_free()

	for _i in range(THINGY_SLOTS):
		var thingy_scene : PackedScene = run.get_random_thingy_scene()
		if not thingy_scene:
			continue

		var thingy     : Thingy = thingy_scene.instantiate()
		var rarity     : int    = thingy.get("rarity") if thingy.get("rarity") != null else 0
		var price               := _thingy_price(rarity)
		var thingy_name         := thingy.name.replace("@", "").strip_edges()
		var desc                := thingy.get_description_with_values()
		var icon_tex            := thingy.texture
		thingy.queue_free()

		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = thingy_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_lbl)

		var rarity_lbl := Label.new()
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.text = _rarity_label(rarity)
		rarity_lbl.add_theme_color_override("font_color", _rarity_color(rarity))
		slot.add_child(rarity_lbl)

		if desc != "":
			var desc_lbl := RichTextLabel.new()
			desc_lbl.bbcode_enabled = true
			desc_lbl.fit_content = true
			desc_lbl.custom_minimum_size = Vector2(130, 0)
			desc_lbl.parse_bbcode(desc)
			slot.add_child(desc_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy  (%d Gold)" % price
		buy_btn.pressed.connect(_on_buy_thingy.bind(thingy_scene, price, buy_btn))
		slot.add_child(buy_btn)

		thingy_container.add_child(slot)

func _on_buy_thingy(thingy_scene: PackedScene, price: int, btn: Button) -> void:
	if run.character.gold < price:
		_flash_button(btn, "Need %d Gold!" % price)
		return
	run.character.gold -= price
	var thingy : Thingy = thingy_scene.instantiate()
	run.add_thingy(thingy)
	btn.text = "Purchased!"
	btn.disabled = true
	_refresh_gold_label()

# ─── Remove card ──────────────────────────────────────────────────────────────

func _on_remove_card_pressed() -> void:
	if run.character.gold < REMOVE_COST:
		_flash_button(remove_card_button, "Need %d Gold!" % REMOVE_COST)
		return
	remove_vbox.visible = true
	_populate_deck_for_removal()

func _populate_deck_for_removal() -> void:
	for child in deck_container.get_children():
		child.queue_free()

	if run.deck.is_empty():
		var lbl := Label.new()
		lbl.text = "Your deck is empty."
		deck_container.add_child(lbl)
		return

	# One button per card — shows name and cost, fits any deck size on screen
	for card_data in run.deck:
		var btn := Button.new()
		btn.text = "%s  (Cost: %d)  [%s]" % [
			card_data.card_name,
			card_data.card_cost,
			_rarity_label(card_data.get("rarity") if card_data.get("rarity") != null else 0)
		]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_remove_card_selected.bind(card_data))
		deck_container.add_child(btn)

func _on_remove_card_selected(card_data: CardData) -> void:
	run.character.gold -= REMOVE_COST
	run.deck.erase(card_data)
	_refresh_gold_label()
	_refresh_remove_button()
	remove_vbox.visible = false

func _on_cancel_remove_pressed() -> void:
	remove_vbox.visible = false

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
