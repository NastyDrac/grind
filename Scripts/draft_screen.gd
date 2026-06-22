extends CanvasLayer
class_name DraftScreen

var run : RunManager
var card_path = preload("res://Scenes/draftable_card.tscn")
var _draft_context : String = "draft"   # set per offer; "draft" or "boss"


signal draft_completed
signal card_drafted(card_data: CardData)


@onready var skip_button: Button = $CenterContainer/draft_screen/VBoxContainer/Button
@onready var card_container: HBoxContainer = $CenterContainer/draft_screen/VBoxContainer/HBoxContainer

func _ready():
	
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func display_card_options(run_manager : RunManager, only_rarity : int = -1):
	run = run_manager
	# Heuristic: the only forced-Rare caller is the boss reward draft.
	_draft_context = "boss" if only_rarity == CardData.RARITY.Rare else "draft"
	var card_data : Array = []
	var offered_card_paths : Array[String] = []

	for each : int in run_manager.draft_amount:
		var random_card = run_manager.get_random_card_data(offered_card_paths, only_rarity)
		if random_card:
			card_data.append(random_card)
			if random_card.resource_path != "":
				offered_card_paths.append(random_card.resource_path)

	# Telemetry: the full offered set, so pick rate = selected / offered later.
	var offered_names : Array = []
	for c in card_data:
		offered_names.append(c.card_name)
	Global.cards_offered.emit(offered_names, _draft_context)


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
	
	run.add_card_to_deck(data)
	
	# Telemetry: the player picked this card from the offered draft set.
	Global.card_selected.emit(data.card_name, _draft_context)
	
	card_drafted.emit(data)
	
	draft_completed.emit()
	
	if run:
		run.close_draft_screen()
