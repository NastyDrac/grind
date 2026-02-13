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
	for action : Action in data.actions:
		if action.max_range > 0:
			desc += "Range : " + str(action.max_range) + "\n"
		desc += action.get_description_with_values(player)
	
	
	var regex = RegEx.new()
	regex.compile("§(\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	
	
	desc = desc.replace("swag", "[img=36x36]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=36x36]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=36x36]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=36x36]res://Art/hustle.png[/img]")
	desc = desc.replace("bang", "[img=36x36]res://Art/bang.png[/img]")
	desc = desc.replace("mojo", "[img=36x36]res://Art/mojo.png[/img]")
	
	description.parse_bbcode(desc)

func _show_description_without_player():
	"""Show card description when no player exists (during events)"""
	if not data:
		return
	
	var desc = ""
	
	for action : Action in data.actions:
		if action.max_range > 0:
			desc += "Range: " + str(action.max_range) + "\n"
		
		
		if action.has_method("get_description_with_values"):
			
			var action_desc = action.get_description_with_values(null)
			if action_desc and action_desc != "":
				desc += action_desc + "\n"
		elif action.has_method("get_base_description"):
			desc += action.get_base_description() + "\n"
		else:
		
			if action.has("description") and action.description:
				desc += action.description + "\n"
	
	
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
	
	description.parse_bbcode(desc)

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
	"""Called when add button is pressed"""
	card_selected.emit(data, "add")



func _on_mouse_entered() -> void:
	hovered = true

func _on_mouse_exited() -> void:
	hovered = false

func _process(delta: float) -> void:
	if hovered and Input.is_action_just_pressed("left click"):
		card_selected.emit(data)
