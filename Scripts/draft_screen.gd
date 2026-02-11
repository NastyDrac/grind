extends CanvasLayer
class_name DraftScreen

var run : RunManager
var card_path = preload("res://Scenes/draftable_card.tscn")

# Signals
signal draft_completed
signal card_drafted(card_data: CardData)

# Reference to the skip button from the scene
@onready var skip_button: Button = $CenterContainer/draft_screen/VBoxContainer/Button
@onready var card_container: HBoxContainer = $CenterContainer/draft_screen/VBoxContainer/HBoxContainer

func _ready():
	# Connect the skip button that's already in the scene
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func display_card_options(run_manager : RunManager):
	run = run_manager
	var card_data : Array = []
	
	# Get random cards based on draft_amount
	for each : int in run_manager.draft_amount:
		var random_card = run_manager.get_random_card_data()
		if random_card:
			card_data.append(random_card)
	
	# Clear any existing cards first
	if card_container:
		for child in card_container.get_children():
			child.queue_free()
	
	# Create card display for each random card
	for each in card_data:
		var card : DraftableCard = card_path.instantiate()
		card_container.add_child(card)
		card.set_data(each)
		card.current_mode = card.Mode.ADD_ONLY
		card.card_selected.connect(add_card_to_deck)

func _on_skip_pressed():
	"""Called when skip button is pressed - finish the draft"""
	draft_completed.emit()
	
	# Close the draft screen
	if run:
		run.close_draft_screen()

func add_card_to_deck(data : CardData):
	"""Called when a card is selected"""
	# Add card to deck
	run.deck.append(data)
	
	# Emit signal that a card was drafted
	card_drafted.emit(data)
	
	# Automatically finish draft after selecting one card
	draft_completed.emit()
	
	# Close the draft screen
	if run:
		run.close_draft_screen()
