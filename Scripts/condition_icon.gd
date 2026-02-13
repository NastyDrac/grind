extends TextureRect
class_name ConditionIcon

@export var condition: Condition


const TOOLTIP_SCENE = preload("res://Scenes/tooltip.tscn")  
var tooltip_instance: Control = null

func _init(con: Condition) -> void:
	set_condition(con)

func _ready():
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	
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
	
	_show_tooltip()

func _on_mouse_exited():
	
	_hide_tooltip()

func _show_tooltip():
	
	if tooltip_instance:
		return
	
	
	tooltip_instance = TOOLTIP_SCENE.instantiate()
	
	
	var canvas_layer = get_tree().root.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(tooltip_instance)
	else:
		get_tree().root.add_child(tooltip_instance)
	
	
	_populate_tooltip()
	
	_position_tooltip()

func _hide_tooltip():
	if tooltip_instance:
		tooltip_instance.queue_free()
		tooltip_instance = null

func _populate_tooltip():
	if not tooltip_instance or not condition:
		return
	
	var icon_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/condition_icon")
	var name_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/condition_name")
	var desc_node = tooltip_instance.get_node_or_null("MarginContainer/VBoxContainer/condition_description")
	
	if icon_node and condition.icon:
		icon_node.texture = condition.icon
	
	if name_node:
		name_node.text = condition.get_condition_name()
	
	if desc_node:
		var description_text = condition.description if condition.description else "No description available."
		
		if condition.stacks > 0:
			description_text = "[b]Stacks:[/b] %d\n%s" % [condition.stacks, description_text]
		desc_node.text = description_text

func _position_tooltip():
	if not tooltip_instance:
		return
	
	
	await get_tree().process_frame
	
	
	var icon_global_pos = global_position
	var icon_size = size
	
	
	var viewport_size = get_viewport_rect().size
	
	
	var tooltip_pos = icon_global_pos + Vector2(icon_size.x + 10, 0)
	
	
	if tooltip_pos.x + tooltip_instance.size.x > viewport_size.x:
		tooltip_pos.x = icon_global_pos.x - tooltip_instance.size.x - 10
	
	
	if tooltip_pos.y + tooltip_instance.size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_instance.size.y - 10
	
	
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	tooltip_instance.global_position = tooltip_pos


func _exit_tree():
	_hide_tooltip()
