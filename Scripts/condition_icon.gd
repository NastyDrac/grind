extends TextureRect
class_name ConditionIcon

@export var condition: Condition

# Tooltip scene to instance
const TOOLTIP_SCENE = preload("res://Scenes/tooltip.tscn")  # Adjust path as needed
var tooltip_instance: Control = null

func _init(con: Condition) -> void:
	set_condition(con)

func _ready():
	# Enable mouse detection
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_condition(con: Condition):
	condition = con
	update_display()

func update_display():
	if condition and condition.icon:
		texture = condition.icon

func _on_mouse_entered():
	if not condition:
		return
	
	# Create and show tooltip
	_show_tooltip()

func _on_mouse_exited():
	# Hide and destroy tooltip
	_hide_tooltip()

func _show_tooltip():
	# Don't create multiple tooltips
	if tooltip_instance:
		return
	
	# Instance the tooltip scene
	tooltip_instance = TOOLTIP_SCENE.instantiate()
	
	# Add tooltip to the canvas layer or root to ensure it's on top
	# You can adjust this based on your scene structure
	var canvas_layer = get_tree().root.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(tooltip_instance)
	else:
		get_tree().root.add_child(tooltip_instance)
	
	# Populate tooltip with condition data
	_populate_tooltip()
	
	# Position tooltip near the icon
	_position_tooltip()

func _hide_tooltip():
	if tooltip_instance:
		tooltip_instance.queue_free()
		tooltip_instance = null

func _populate_tooltip():
	if not tooltip_instance or not condition:
		return
	
	# Find the nodes in the tooltip scene
	var icon_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/condition_icon")
	var name_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/condition_name")
	var desc_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/condition_description")
	
	# Set the icon
	if icon_node and condition.icon:
		icon_node.texture = condition.icon
	
	# Set the name
	if name_node:
		name_node.text = condition.get_condition_name()
	
	# Set the description
	if desc_node:
		var description_text = condition.description if condition.description else "No description available."
		# If the condition has stacks, add that info
		if condition.stacks > 0:
			description_text = "[b]Stacks:[/b] %d\n%s" % [condition.stacks, description_text]
		desc_node.text = description_text

func _position_tooltip():
	if not tooltip_instance:
		return
	
	# Wait one frame for tooltip to calculate its size
	await get_tree().process_frame
	
	# Get the global position of this icon
	var icon_global_pos = global_position
	var icon_size = size
	
	# Get viewport size to prevent tooltip from going off-screen
	var viewport_size = get_viewport_rect().size
	
	# Position tooltip to the right of the icon by default
	var tooltip_pos = icon_global_pos + Vector2(icon_size.x + 10, 0)
	
	# Check if tooltip would go off the right edge
	if tooltip_pos.x + tooltip_instance.size.x > viewport_size.x:
		# Position to the left instead
		tooltip_pos.x = icon_global_pos.x - tooltip_instance.size.x - 10
	
	# Check if tooltip would go off the bottom
	if tooltip_pos.y + tooltip_instance.size.y > viewport_size.y:
		# Adjust up
		tooltip_pos.y = viewport_size.y - tooltip_instance.size.y - 10
	
	# Check if tooltip would go off the top
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	tooltip_instance.global_position = tooltip_pos

# Cleanup when icon is removed
func _exit_tree():
	_hide_tooltip()
