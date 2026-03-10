extends Control
class_name DraftableCard

@export var data : CardData
signal card_selected(card_data: CardData) 

var hovered : bool = false
@onready var title = $BlankCard/title
@onready var description : RichTextLabel = $BlankCard/description
@onready var cost = $BlankCard/cost

var player_reference : Character = null
var is_in_deck : bool = false
var card_count : int = 0  
var max_copies : int = 3  
var connection_attempts : int = 0  
var max_connection_attempts : int = 10 

enum Mode {
	ADD_ONLY,      
	REMOVE_ONLY,   
	ADD_REMOVE,    
	DISPLAY_ONLY   
}

var current_mode : Mode = Mode.DISPLAY_ONLY

func set_data(card_data : CardData):
	data = card_data
	if is_node_ready():
		_setup_card()

func _setup_card():
	title.text = data.card_name
	cost.text = str(data.card_cost)
	if description is RichTextLabel:
		description.bbcode_enabled = true
	
	refresh_description()

	_connect_to_player_stats()

func refresh_description():
	if not data:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		_show_description_without_player()
		return
	
	var desc = ""
	var action_count = data.actions.size()
	
	for i in range(action_count):
		var action : Action = data.actions[i]
		desc += action.get_description_with_values(player)
		if i < action_count - 1:
			desc += "\n"
	
	var regex = RegEx.new()
	regex.compile("§(\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	
	desc = desc.replace("swag", "[img=16x16]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=16x16]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=16x16]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=16x16]res://Art/hustle.png[/img]")
	desc = desc.replace("bang", "[img=16x16]res://Art/bang.png[/img]")
	desc = desc.replace("mojo", "[img=16x16]res://Art/mojo.png[/img]")
	
	# Keyword tags
	var keyword_prefix := ""
	var keyword_suffix := ""
	if data.volatile:
		keyword_prefix += "[b][color=orange]Volatile[/color][/b]\n"
	if data.fickle:
		keyword_prefix += "[b][color=purple]Fickle[/color][/b]\n"
	if data.exhaust:
		keyword_suffix += "\n[b][color=red]Exhaust[/color][/b]"
	
	description.parse_bbcode(keyword_prefix + desc + keyword_suffix)

func _show_description_without_player():
	if not data:
		return
	
	var desc = ""
	var action_count = data.actions.size()
	
	for i in range(action_count):
		var action : Action = data.actions[i]
		
		if action.has_method("get_description_with_values"):
			var action_desc = action.get_description_with_values(null)
			if action_desc and action_desc != "":
				desc += action_desc
		elif action.has_method("get_base_description"):
			desc += action.get_base_description()
		else:
			if action.has("description") and action.description:
				desc += action.description
		
		if i < action_count - 1:
			desc += "\n"
	
	if desc.strip_edges() == "":
		desc = "[i]Preview mode - full details available in combat[/i]"
	
	var regex = RegEx.new()
	regex.compile("§(\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	
	desc = desc.replace("swag", "[img=36x36]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=36x36]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=36x36]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=36x36]res://Art/hustle.png[/img]")
	desc = desc.replace("bang", "[img=36x36]res://Art/bang.png[/img]")
	desc = desc.replace("mojo", "[img=36x36]res://Art/mojo.png[/img]")
	
	# Keyword tags
	var keyword_prefix := ""
	var keyword_suffix := ""
	if data.volatile:
		keyword_prefix += "[b][color=orange]Volatile[/color][/b]\n"
	if data.fickle:
		keyword_prefix += "[b][color=purple]Fickle[/color][/b]\n"
	if data.exhaust:
		keyword_suffix += "\n[b][color=red]Exhaust[/color][/b]"
	
	description.parse_bbcode(keyword_prefix + desc + keyword_suffix)

func _connect_to_player_stats():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		connection_attempts += 1
		if connection_attempts < max_connection_attempts:
			call_deferred("_connect_to_player_stats")
		return
	
	if not player.has_signal("stats_changed"):
		return
	
	if player_reference and player_reference.stats_changed.is_connected(_on_player_stats_changed):
		player_reference.stats_changed.disconnect(_on_player_stats_changed)
	
	player.stats_changed.connect(_on_player_stats_changed)
	player_reference = player

func _on_player_stats_changed():
	refresh_description()

func _on_add_pressed():
	card_selected.emit(data, "add")

func _on_mouse_entered() -> void:
	hovered = true

func _on_mouse_exited() -> void:
	hovered = false

func _process(delta: float) -> void:
	if hovered and Input.is_action_just_pressed("left click"):
		card_selected.emit(data)
