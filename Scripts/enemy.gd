extends Node2D
class_name Enemy

var data : EnemyData
var current_health : int
var max_health : int
var current_range : int = 5

var range_manager : RangeManager
var target_position : Vector2
var movement_speed : float = 10.0
var selectable : bool = false
var is_targeted : bool = false
var conditions : Array[Condition] = []
var run_manager 

var _hover_tween : Tween = null
var _is_hovered : bool = false
var _enemy_tooltip : Control = null

#signal enemy_attack_player(enemy : Enemy, damage : int)
#signal enemy_moved(enemy : Enemy, old_range : int, new_range : int)
#signal enemy_player_moved(enemy : Enemy, old_range : int, new_range : int)

@onready var sprite := $Sprite2D

@onready var selection_highlight = $SelectionHighlight if has_node("SelectionHighlight") else null
@onready var target_highlight = $TargetHighlight if has_node("TargetHighlight") else null
@onready var health_bar = $health_bar

func _ready():
	
	Global.time_passed.connect(_on_enemies_advance)
	Global.apply_condition.connect(_on_apply_condition)  
	
	
	if selection_highlight:
		selection_highlight.visible = false
	if target_highlight:
		target_highlight.visible = false


func _on_apply_condition(target, condition_to_apply: Condition):
	if target != self:
		return
	
	
	condition_to_apply.apply_condition(self, condition_to_apply)

func resize_collision_shape():
	$Sprite2D/Area2D/CollisionShape2D.shape.size = data.texture.get_size()
	health_bar.position.y -= get_visual_height()/2 + health_bar.get_rect().size.y/2

func set_range_manager(manager : RangeManager):
	range_manager = manager

func set_data(enemy_data: EnemyData, spawn_range : int = 5):
	data = enemy_data.duplicate()
	max_health = randi_range(data.min_health, data.max_health)
	current_health = max_health
	current_range = spawn_range
	sprite.texture = data.texture
	resize_collision_shape()
	set_health_bar()
	if data.conditions and data.conditions.size() > 0:
		for condition in data.conditions:
			condition.apply_condition(self, condition)

func take_damgage(amount : int):
	current_health -= amount
	for con : Condition in conditions:
		if con.has_method("on_take_damage"):
			con.on_take_damage(amount)
	set_health_bar()
	Animations._flash_red(self, .2)
	if current_health <= 0:
		die()

func die():
	Global.enemy_dies.emit(self)
	remove_all_conditions()
	_hide_enemy_tooltip()
	queue_free()

func remove_all_conditions():
	for con : Condition in conditions:
		con.remove_condition(self)
# 
func _on_enemies_advance():
	# In sequential mode the range_manager picks which enemy moves — not all at once.
	if range_manager and range_manager.sequential_movement:
		return
	move_toward_player()

func move_toward_player():
	if data.move_pattern:
		var step = data.move_pattern.get_active_step(self)
		if step:
			_execute_action(step.action)
			return
	# Default behavior — no pattern assigned, or no step matched.
	if current_range <= data.attack_range:
		attack_player()
		return
	_do_advance()


# ── Movement primitives ───────────────────────────────────────────────────────

func _do_advance() -> void:
	var old_range := current_range
	current_range = max(1, current_range - data.move_speed)
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
	Global.enemy_advanced.emit(self, old_range, current_range)


func _do_retreat() -> void:
	var old_range := current_range
	# Use the initialised dictionary size so this automatically respects any
	# future change to the max range passed into _initialize_ranges().
	var max_range := range_manager.enemies_by_range.size() - 1 if range_manager else 5
	current_range = min(max_range, current_range + data.move_speed)
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
	Global.enemy_advanced.emit(self, old_range, current_range)


func _execute_action(action: MoveStep.MoveAction) -> void:
	match action:
		MoveStep.MoveAction.ADVANCE:
			_do_advance()
		MoveStep.MoveAction.RETREAT:
			_do_retreat()
		MoveStep.MoveAction.HOLD:
			pass  # Intentionally do nothing.
		MoveStep.MoveAction.ATTACK:
			if current_range <= data.attack_range:
				attack_player()
			else:
				_do_advance()
		MoveStep.MoveAction.ATTACK_THEN_RETREAT:
			if current_range <= data.attack_range:
				attack_player()
			_do_retreat()
		MoveStep.MoveAction.ATTACK_THEN_ADVANCE:
			if current_range <= data.attack_range:
				attack_player()
			_do_advance()


## Returns what this enemy will do on the next advance, given its current state.
## Used by IntentIndicator to preview the upcoming action without executing it.
func get_next_intent() -> MoveStep.MoveAction:
	if data and data.move_pattern:
		var step = data.move_pattern.get_active_step(self)
		if step:
			return step.action
	# Mirror default behavior.
	if current_range <= data.attack_range:
		return MoveStep.MoveAction.ATTACK
	return MoveStep.MoveAction.ADVANCE


func attack_player():
	Global.enemy_attacks_player.emit(self, get_attack_damage())

func get_attack_damage() -> int:

	var mod_amount = data.damage
	for con : Condition in conditions:
		if con.has_method("modify_attack"):
			mod_amount += con.modify_attack()
	
	return mod_amount
## Push this enemy away from the player by the given number of range steps.
## Always use this for push effects — it emits enemy_moved so the range manager
## stays in sync, and enemy_player_moved so Newton's Cradle (player-only) fires.
func push(amount: int) -> void:
	if amount <= 0:
		return
	var old_range := current_range
	current_range += amount
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
	Global.enemy_advanced.emit(self, old_range, current_range)
	#enemy_player_moved.emit(self, old_range, current_range)

func get_current_range() -> int:
	return current_range

func is_alive() -> bool:
	return current_health > 0

func _process(delta: float) -> void:
	if range_manager:
		target_position = range_manager.get_position_for_enemy(self)
		position = position.lerp(target_position, movement_speed * delta)

func _on_area_2d_mouse_entered() -> void:
	range_manager.enemy_hovered = self
	if not range_manager.targeting or selectable:
		_show_hover_feedback()
	
func _on_area_2d_mouse_exited() -> void:
	if range_manager and range_manager.enemy_hovered == self:
		range_manager.enemy_hovered = null
	_hide_hover_feedback()

func get_visual_height() -> float:
	if has_node("Sprite2D"):
		return $Sprite2D.texture.get_height() * $Sprite2D.scale.y
	return 100.0

func set_health_bar():
	health_bar.max_value = max_health
	health_bar.value = current_health
	$health_bar/Label.text = str(current_health)

# ============================================================================
# TARGETING VISUAL FEEDBACK
# ============================================================================

func make_selectable():
	if not selectable:
		selectable = true
		_update_visual_state()

func make_unselectable():
	if selectable:
		selectable = false
		_update_visual_state()

func set_targeted(targeted: bool):
	is_targeted = targeted
	_update_visual_state()

func _update_visual_state():
	
	if selection_highlight:
		selection_highlight.visible = selectable and not is_targeted
	
	
	if target_highlight:
		target_highlight.visible = is_targeted
	
	if not selection_highlight and not target_highlight:
		if is_targeted:
			sprite.modulate = Color(0.0, 0.43, 0.756, 1.0) 
		elif selectable:
			sprite.modulate = Color(1.0, 1.0, 1.0)  
		else:
			sprite.modulate = Color(0.7, 0.7, 0.7)  

func _show_hover_feedback():
	if not is_targeted:
		if selection_highlight:
			selection_highlight.modulate = Color(1.2, 1.2, 1.2)  
		elif not target_highlight:
			sprite.modulate = Color(1.2, 1.2, 1.2)

	# Mark as hovered so _hide_hover_feedback knows a scale-up actually happened
	_is_hovered = true

	# Scale up with a snappy pop — TRANS_BACK/EASE_OUT overshoots slightly on
	# the way UP, which looks great. It only overshoots on the end of the motion,
	# not the start, so there is no unwanted upward kick on hide.
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(sprite, "scale", Vector2(.75, .75), 0.15)

	_show_enemy_tooltip()

func _hide_hover_feedback():
	if not is_targeted:
		if selection_highlight:
			selection_highlight.modulate = Color(1.0, 1.0, 1.0) 
		elif not target_highlight:
			_update_visual_state()

	# Only animate the scale back if it was actually scaled up. Without this guard,
	# _hide_hover_feedback (which fires unconditionally on mouse exit) would create
	# a tween even when the enemy was never hovered, causing a rogue scale kick.
	if _is_hovered:
		_is_hovered = false
		if _hover_tween:
			_hover_tween.kill()
		# TRANS_SINE/EASE_IN shrinks smoothly with no overshoot — using TRANS_BACK
		# here was the cause of the unwanted scale-up on mouse exit.
		_hover_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_hover_tween.tween_property(sprite, "scale", Vector2(.5, .5), 0.12)

	_hide_enemy_tooltip()

# ============================================================================
# ENEMY TOOLTIP
# ============================================================================

func _show_enemy_tooltip():
	if _enemy_tooltip:
		return

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.45, 0.6, 1.0)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Enemy name
	var name_label := Label.new()
	name_label.text = data.enemy_name if data else "Enemy"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(name_label)

	# Only show conditions block if there are any
	if conditions.size() > 0:
		vbox.add_child(HSeparator.new())

		for con: Condition in conditions:
			# Name + stacks row
			var con_name: String = con.get_condition_name() if con.has_method("get_condition_name") else "Unknown"
			var stacks_text: String = " (x%d)" % con.stacks if con.show_stacks and con.stacks > 1 else ""

			var con_row := HBoxContainer.new()
			con_row.add_theme_constant_override("separation", 4)

			if con.icon:
				var icon_rect := TextureRect.new()
				icon_rect.texture = con.icon
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = Vector2(16, 16)
				icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				con_row.add_child(icon_rect)

			var con_name_label := Label.new()
			con_name_label.text = "%s%s" % [con_name, stacks_text]
			con_name_label.add_theme_font_size_override("font_size", 12)
			con_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
			con_row.add_child(con_name_label)

			vbox.add_child(con_row)

			# Description (mirrors what ConditionIcon._populate_tooltip shows)
			if con.has_method("get_description_with_values"):
				var desc_label := Label.new()
				desc_label.text = con.get_description_with_values()
				desc_label.add_theme_font_size_override("font_size", 11)
				desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				desc_label.custom_minimum_size.x = 180.0
				vbox.add_child(desc_label)

	panel.add_child(vbox)
	_enemy_tooltip = panel

	var tooltip_layer := get_tree().root.get_node_or_null("TooltipLayer")
	if not tooltip_layer:
		tooltip_layer = CanvasLayer.new()
		tooltip_layer.name = "TooltipLayer"
		tooltip_layer.layer = 100
		get_tree().root.add_child(tooltip_layer)

	tooltip_layer.add_child(_enemy_tooltip)
	_position_enemy_tooltip()

func _hide_enemy_tooltip():
	if _enemy_tooltip:
		_enemy_tooltip.queue_free()
		_enemy_tooltip = null

func _position_enemy_tooltip():
	if not _enemy_tooltip:
		return

	await get_tree().process_frame

	if not is_instance_valid(_enemy_tooltip):
		return

	var viewport_size := get_viewport_rect().size
	var screen_pos    := get_global_transform_with_canvas().origin
	var tooltip_pos   := screen_pos + Vector2(get_visual_height() * 0.5 + 10.0, -_enemy_tooltip.size.y * 0.5)

	# Keep inside viewport horizontally
	if tooltip_pos.x + _enemy_tooltip.size.x > viewport_size.x:
		tooltip_pos.x = screen_pos.x - _enemy_tooltip.size.x - 10.0

	# Keep inside viewport vertically
	tooltip_pos.y = clamp(tooltip_pos.y, 10.0, viewport_size.y - _enemy_tooltip.size.y - 10.0)

	_enemy_tooltip.global_position = tooltip_pos

func _exit_tree():
	_hide_enemy_tooltip()
