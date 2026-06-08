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
		desc += action.get_card_text(player)
		if i < action_count - 1:
			desc += "\n"
	
	var regex = RegEx.new()
	regex.compile("§([+\\-]?\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	
	desc = desc.replace("swag", "[img=16x16]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=16x16]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=16x16]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=16x16]res://Art/hustle.png[/img]")
	desc = desc.replace("heat", "[img=16x16]res://Art/heat.png[/img]")
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
		
		if action.has_method("get_card_text"):
			var action_desc = action.get_card_text(null)
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
	regex.compile("§([+\\-]?\\d+)§")
	desc = regex.sub(desc, "[color=green]$1[/color]", true)
	
	desc = desc.replace("swag", "[img=36x36]res://Art/swag.png[/img]")
	desc = desc.replace("marbles", "[img=36x36]res://Art/marbles.png[/img]")
	desc = desc.replace("guts", "[img=36x36]res://Art/guts.png[/img]")
	desc = desc.replace("hustle", "[img=36x36]res://Art/hustle.png[/img]")
	desc = desc.replace("heat", "[img=36x36]res://Art/heat.png[/img]")
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
	_show_tooltip()

func _on_mouse_exited() -> void:
	hovered = false
	_hide_tooltip()

func _exit_tree() -> void:
	_hide_tooltip()

func _process(delta: float) -> void:
	if hovered and Input.is_action_just_pressed("left click"):
		card_selected.emit(data)


# ── Hover tooltip (formula breakdown + keyword condition explanations) ──────────
# DraftableCards aren't managed by card_handler, so they carry their own minimal
# tooltip. Reuses the shared high-layer "TooltipLayer".
var _tooltip_instance : Control = null

func get_card_tooltip_text() -> String:
	if not data:
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return ""
	var lines : Array[String] = []
	for action in data.actions:
		if action == null:
			continue
		if action.has_method("get_tooltip_text"):
			var t : String = action.get_tooltip_text(player)
			if t != "":
				lines.append(t)
	return "\n".join(lines)

func _show_tooltip() -> void:
	if _tooltip_instance:
		return
	var text := get_card_tooltip_text()
	if text == "":
		return

	var layer := get_tree().root.get_node_or_null("TooltipLayer")
	if not layer:
		layer = CanvasLayer.new()
		layer.name = "TooltipLayer"
		get_tree().root.add_child(layer)
	# Force above modal CanvasLayers (e.g. the deck viewer sits at layer 100).
	layer.layer = 1000

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	margin.add_child(lbl)

	layer.add_child(panel)
	_tooltip_instance = panel
	panel.visible = false
	_position_tooltip()

func _hide_tooltip() -> void:
	if _tooltip_instance:
		_tooltip_instance.queue_free()
		_tooltip_instance = null

func _position_tooltip() -> void:
	if not _tooltip_instance:
		return
	# Let layout settle so size is known before placing.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _tooltip_instance:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var size := _tooltip_instance.size
	var view := get_viewport_rect().size
	var m := 10.0
	var pos := mouse_pos + Vector2(m, m)
	if pos.x + size.x > view.x - m:
		pos.x = mouse_pos.x - size.x - m
	if pos.y + size.y > view.y - m:
		pos.y = mouse_pos.y - size.y - m
	pos.x = clampf(pos.x, m, view.x - size.x - m)
	pos.y = clampf(pos.y, m, view.y - size.y - m)
	_tooltip_instance.global_position = pos
	_tooltip_instance.visible = true
