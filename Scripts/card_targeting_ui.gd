extends CanvasLayer
class_name CardTargetingUI

# UI Elements
var panel: PanelContainer
var label: Label
var confirm_button: Button
var cancel_button: Button

# State
var selected_cards: Array[Card] = []
var max_selections: int = 1
var callback: Callable

signal selection_confirmed(cards: Array[Card])
signal selection_cancelled()

func _ready():
	_create_ui()
	hide()
	_create_selection_highlight()
func _create_ui():
	# Main panel at top of screen
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 20
	panel.offset_bottom = 100
	add_child(panel)
	
	# Container for label and buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	
	# Instruction label
	label = Label.new()
	label.text = "Select a card"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(spacer)
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	hbox.add_child(confirm_button)
	
	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Right-Click)"
	cancel_button.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_button)

func show_targeting(instruction: String, max_cards: int = 1):
	"""Show the targeting UI with custom instruction"""
	label.text = instruction
	max_selections = max_cards
	selected_cards.clear()
	confirm_button.disabled = true
	show()

func hide_targeting():
	"""Hide the targeting UI"""
	selected_cards.clear()
	hide()

func add_selected_card(card: Card):
	"""Add a card to the selection"""
	if card in selected_cards:
		# Deselect if already selected
		selected_cards.erase(card)
		card.set_selected(false)
	else:
		# Add to selection if room
		if selected_cards.size() < max_selections:
			selected_cards.append(card)
			card.set_selected(true)
		else:
			# Replace the first selection if at max
			var old_card = selected_cards[0]
			old_card.set_selected(false)
			selected_cards[0] = card
			card.set_selected(true)
	
	# Update UI
	_update_ui()

func _update_ui():
	"""Update button states and label"""
	confirm_button.disabled = selected_cards.is_empty()
	
	if selected_cards.size() > 0:
		var card_names = []
		for card in selected_cards:
			card_names.append(card.data.card_name)
		label.text = "Selected: %s (Click to confirm)" % ", ".join(card_names)
	else:
		label.text = "Select a card"

func _on_confirm_pressed():
	selection_confirmed.emit(selected_cards.duplicate())
	hide_targeting()

func _on_cancel_pressed():
	# Deselect all cards
	for card in selected_cards:
		card.set_selected(false)
	selection_cancelled.emit()
	hide_targeting()

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_accept"):
		# Allow Enter/Space to confirm
		if not confirm_button.disabled:
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()

# Add this to your Card class (card.gd)

# Visual selection feedback
var is_selected_for_targeting: bool = false
var selection_highlight: ColorRect


func _create_selection_highlight():
	"""Create a highlight overlay for when card is selected"""
	selection_highlight = ColorRect.new()
	selection_highlight.color = Color(1, 1, 0, 0.3)  # Yellow semi-transparent
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_highlight.visible = false
	
	# Make it cover the whole card
	selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(selection_highlight)
	selection_highlight.z_index = -1  # Behind card content

func set_selected(selected: bool):
	"""Toggle selection highlight"""
	is_selected_for_targeting = selected
	if selection_highlight:
		selection_highlight.visible = selected
		
		# Optional: Add a pulse animation
		if selected:
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(selection_highlight, "color:a", 0.5, 0.5)
			tween.tween_property(selection_highlight, "color:a", 0.3, 0.5)

func set_selectable(selectable: bool):
	"""Visual feedback that card can be selected (optional)"""
	# You could add a subtle glow or border here
	# For now, we'll just use the hover effect
	pass
