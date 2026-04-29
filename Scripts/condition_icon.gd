extends TextureRect
class_name ConditionIcon

var condition: Condition

const TOOLTIP_SCENE = preload("res://Scenes/tooltip.tscn")
var tooltip_instance: Control = null
var stacks_label: Label = null



func _ready():
	custom_minimum_size = Vector2(16, 16)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_setup_stacks_label()

func _setup_stacks_label():
	stacks_label = Label.new()
	stacks_label.anchor_right = 1.0
	stacks_label.anchor_bottom = 1.0
	stacks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stacks_label.add_theme_font_size_override("font_size", 12)
	stacks_label.add_theme_color_override("font_color", Color.WHITE)
	stacks_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	stacks_label.add_theme_constant_override("shadow_offset_x", 1)
	stacks_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(stacks_label)

func set_condition(con: Condition):
	condition = con
	update_display()

func update_display():
	if condition and condition.icon:
		texture = condition.icon

	if stacks_label:
		if condition and condition.show_stacks:
			stacks_label.text = str(condition.stacks)
			stacks_label.visible = true
		else:
			stacks_label.visible = false

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

	# Always add the tooltip to a dedicated high-layer CanvasLayer so it
	# renders above every other UI element, including Shop and popups.
	var tooltip_layer := get_tree().root.get_node_or_null("TooltipLayer")
	if not tooltip_layer:
		tooltip_layer = CanvasLayer.new()
		tooltip_layer.name = "TooltipLayer"
		tooltip_layer.layer = 100
		get_tree().root.add_child(tooltip_layer)

	tooltip_layer.add_child(tooltip_instance)
	tooltip_instance.visible = false

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

	if not desc_node:
		push_warning("ConditionIcon: could not find condition_description node in tooltip scene")
		return
	
	var description_text = condition.get_description_with_values()

	if condition.stacks > 0:
		description_text = "[b]Stacks:[/b] %d\n%s" % [condition.stacks, description_text]
	desc_node.text = description_text
	

func _position_tooltip():
	if not tooltip_instance:
		return

	# Two frames: one to enter the tree, one for layout (fit_content RichTextLabel
	# needs the second pass to settle its height before size is correct).
	await get_tree().process_frame
	await get_tree().process_frame

	if not tooltip_instance:
		return

	var mouse_pos     := get_viewport().get_mouse_position()
	var tooltip_size  := tooltip_instance.size
	var viewport_size := get_viewport_rect().size
	var margin        := 10.0

	# Default: just to the right and slightly below the cursor.
	var pos := mouse_pos + Vector2(margin, margin)

	# Right edge — flip to the left of the cursor.
	if pos.x + tooltip_size.x > viewport_size.x - margin:
		pos.x = mouse_pos.x - tooltip_size.x - margin

	# Bottom edge — flip above the cursor.
	if pos.y + tooltip_size.y > viewport_size.y - margin:
		pos.y = mouse_pos.y - tooltip_size.y - margin

	# Hard clamp — keeps it on screen even if both flips still overshoot.
	pos.x = clampf(pos.x, margin, viewport_size.x - tooltip_size.x - margin)
	pos.y = clampf(pos.y, margin, viewport_size.y - tooltip_size.y - margin)

	tooltip_instance.global_position = pos
	tooltip_instance.visible = true

func _exit_tree():
	_hide_tooltip()
