extends Control
class_name Card

@export var data : CardData
signal card_hovered(card : Card)
@onready var title = $BlankCard/title
@onready var description : RichTextLabel = $BlankCard/description
@onready var cost = $BlankCard/cost

var player_reference : Character = null

func _on_mouse_entered() -> void:
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	card_hovered.emit(null)

func set_data(card_data : CardData):
	data = card_data
	title.text = data.card_name
	cost.text = str(data.card_cost)
	
	if description is RichTextLabel:
		description.bbcode_enabled = true
	
	refresh_description()
	

	_connect_to_player_stats()


func refresh_description():
	var swag = preload("res://Art/swag.png")
	var marbles = preload("res://Art/marbles.png")
	var guts = preload("res://Art/guts.png")
	var hustle = preload("res://Art/hustle.png")
	var bang = preload("res://Art/bang.png")
	var mojo = preload("res://Art/marbles.png")
	if not data:
		return
	
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	
	var desc = ""
	for action : Action in data.actions:
		if action.max_range > 0:
			desc += "Range : " + str(action.max_range) + "\n"
		desc += action.get_description_with_values(player)
	
	
	
	var regex = RegEx.new()
	regex.compile("§(\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	desc = desc.replace("swag", "[img=24x24]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=24x24]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=24x24]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=24x24]res://Art/hustle.png[/img]")
	desc = desc.replace("bang", "[img=24x24]res://Art/bang.png[/img]")
	desc = desc.replace("mojo", "[img=24x24]res://Art/mojo.png[/img]")
	

	
	description.parse_bbcode(desc) 


func _ready():
	for each in data.actions:
		var player = get_tree().get_first_node_in_group("player")
		each.player = player

func _connect_to_player_stats():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Retry on next frame when player might be ready
		call_deferred("_connect_to_player_stats")
		return
	
	if not player.has_signal("stats_changed"):
		return
	
	# Disconnect first if already connected (to avoid duplicate connections)
	if player_reference and player_reference.stats_changed.is_connected(_on_player_stats_changed):
		player_reference.stats_changed.disconnect(_on_player_stats_changed)
	
	player.stats_changed.connect(_on_player_stats_changed)
	player_reference = player

func _on_player_stats_changed():
	# When player stats change, refresh this card's description
	refresh_description()
