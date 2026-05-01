extends Control
class_name Card

@export var data : CardData
signal card_hovered(card : Card)
@onready var title = $BlankCard/title
@onready var description : RichTextLabel = $BlankCard/description
@onready var cost = $BlankCard/cost

var player_reference : Character = null

# ── Cost modification ─────────────────────────────────────────────────────────
## Set a specific cost, ignoring modifiers. -1 = inactive (use base cost + modifiers).
var cost_override: int = -1
## Relative adjustments from multiple independent sources (conditions, cards, etc.).
var cost_modifiers: Array[int] = []

func get_cost() -> int:
	if cost_override >= 0:
		return cost_override
	var total = data.card_cost
	for mod in cost_modifiers:
		total += mod
	return max(0, total)

func set_cost_override(new_cost: int) -> void:
	cost_override = new_cost
	cost.text = str(get_cost())

func clear_cost_override() -> void:
	cost_override = -1
	cost.text = str(get_cost())

func add_cost_modifier(amount: int) -> void:
	cost_modifiers.append(amount)
	cost.text = str(get_cost())

func remove_cost_modifier(amount: int) -> void:
	cost_modifiers.erase(amount)
	cost.text = str(get_cost())
# ─────────────────────────────────────────────────────────────────────────────

# Visual selection for card targeting
var is_selected_for_targeting: bool = false
var selection_highlight: ColorRect

func _on_mouse_entered() -> void:
	card_hovered.emit(self)

func _on_mouse_exited() -> void:
	card_hovered.emit(null)

func set_data(card_data : CardData):
	data = card_data
	title.text = data.card_name
	cost.text = str(get_cost())
	
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
	var action_count = data.actions.size()
	
	for i in range(action_count):
		var action : Action = data.actions[i]
		
		# Add the action description (actions now handle their own range display)
		desc += action.get_description_with_values(player)
		
		# Add newline between actions (but not after the last one)
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
	

	
	description.parse_bbcode(desc) 

	# ── Keyword tags ──────────────────────────────────────────────────────
	# Prepend / append keyword lines so they always appear regardless of actions
	var keyword_prefix := ""
	var keyword_suffix := ""
	if data.volatile:
		keyword_prefix += "[b][color=orange]Volatile[/color][/b]\n"
	if data.fickle:
		keyword_prefix += "[b][color=purple]Fickle[/color][/b]\n"
	if data.exhaust:
		keyword_suffix += "\n[b][color=red]Exhaust[/color][/b]"
	
	if keyword_prefix != "" or keyword_suffix != "":
		var full = keyword_prefix + desc + keyword_suffix
		description.parse_bbcode(full)


func _ready():
	for each in data.actions:
		var player = get_tree().get_first_node_in_group("player")
		each.player = player
	
	# Create selection highlight for card targeting
	_create_selection_highlight()

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

# ============================================================================
# CARD TARGETING VISUAL FEEDBACK
# ============================================================================

func _create_selection_highlight():
	"""Create a highlight overlay for when card is selected for targeting"""
	selection_highlight = ColorRect.new()
	selection_highlight.color = Color(1, 1, 0, 0.3)  # Yellow semi-transparent
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_highlight.visible = false
	selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(selection_highlight)
	selection_highlight.z_index = -1  # Behind card content

func set_selected(selected: bool):
	"""Toggle selection highlight - called by card_handler during targeting"""
	is_selected_for_targeting = selected
	if selection_highlight:
		selection_highlight.visible = selected
		
		if selected:
			# Add a pulse animation
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(selection_highlight, "color:a", 0.5, 0.5)
			tween.tween_property(selection_highlight, "color:a", 0.3, 0.5)

func set_selectable(selectable: bool):
	"""Visual feedback that card can be selected (optional)"""
	# You could add a subtle glow or border here if desired
	# For now, we just use the hover effect
	pass
