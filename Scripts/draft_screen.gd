extends CanvasLayer
class_name DraftScreen

var run : RunManager
var card_path = preload("res://Scenes/draftable_card.tscn")


signal draft_completed
signal card_drafted(card_data: CardData)


@onready var skip_button: Button = $CenterContainer/draft_screen/VBoxContainer/Button
@onready var card_container: HBoxContainer = $CenterContainer/draft_screen/VBoxContainer/HBoxContainer

func _ready():
	
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func display_card_options(run_manager : RunManager):
	run = run_manager
	var card_data : Array = []
	
	
	for each : int in run_manager.draft_amount:
		var random_card = run_manager.get_random_card_data()
		if random_card:
			card_data.append(random_card)
	
	
	if card_container:
		for child in card_container.get_children():
			child.queue_free()
	
	
	for each in card_data:
		var card : DraftableCard = card_path.instantiate()
		card_container.add_child(card)
		card.set_data(each)
		card.current_mode = card.Mode.ADD_ONLY
		card.card_selected.connect(add_card_to_deck)

func _on_skip_pressed():
	"""Called when skip button is pressed - finish the draft"""
	draft_completed.emit()
	
	
	if run:
		run.close_draft_screen()

func add_card_to_deck(data : CardData):
	"""Called when a card is selected"""
	
	run.deck.append(data)
	
	
	card_drafted.emit(data)
	
	
	draft_completed.emit()
	
	if run:
		run.close_draft_screen()
