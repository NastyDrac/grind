extends Node
class_name Character

signal stats_changed()

@export var character_data : CharacterData
var stats : Array[Stat]       # combat copies — separate from character_data.stats
var health : int = 0
var block : int = 0

@onready var health_bar = $TextureProgressBar
@onready var sprite = $Sprite2D
@onready var block_display = $TextureProgressBar/ColorRect if has_node("TextureProgressBar/ColorRect") else null
@onready var block_label = $TextureProgressBar/ColorRect/Label if has_node("TextureProgressBar/ColorRect/Label") else null
var run_manager : RunManager
var conditions : Array[Condition] = []
var _cached_max_health : int = 0

func _ready() -> void:
	Global.item_picked_up.connect(collect_item.bind())
	Global.apply_condition.connect(_on_apply_condition)


func _on_apply_condition(target, condition_to_apply: Condition):
	if target != self:
		return
	condition_to_apply.apply_condition(self, condition_to_apply)

func position_character():
	sprite.texture = character_data.character_image
	var range_mgr = get_tree().get_first_node_in_group("range_manager")
	if range_mgr:
		var range_0_x = range_mgr._get_x_for_range(0)
		var viewport_size = get_viewport().size
		var center_y = (range_mgr.y_min + range_mgr.y_max) * 0.5

		var sprite_half_width = 0.0
		if sprite.texture:
			sprite_half_width = (sprite.texture.get_size().x * sprite.scale.x) / 2

		var range_0_position = Vector2(range_0_x, center_y)
		sprite.global_position = range_0_position

		if sprite.texture:
			var sprite_half_height = (sprite.texture.get_size().y * sprite.scale.y) / 2
			var health_bar_width = health_bar.size.x
			health_bar.global_position = range_0_position + Vector2(-health_bar_width / 2, sprite_half_height + 10)
		else:
			health_bar.global_position = range_0_position + Vector2(-64, 50)
	else:
		var center_y = get_viewport().size.y / 3
		var left_x = 100
		sprite.global_position = Vector2(left_x, center_y)
		var health_bar_width = health_bar.size.x
		health_bar.global_position = Vector2(left_x - health_bar_width / 2, center_y + 100)

func take_hit(who : Enemy, damage : int):
	for con : Condition in character_data.special_effects:
		if con.has_method("modify_damage"):
			damage = con.modify_damage(damage)
	if block > 0:
		var absorbed = min(block, damage)
		block -= absorbed
		damage -= absorbed

	if damage > 0:
		health -= damage
		character_data.current_health = health

	if block < 0:
		block = 0

	display_block()
	set_health_bar()
	if run_manager and run_manager.ui_bar:
		run_manager.ui_bar.set_health()

	if health <= 0:
		die()

func set_health_bar():
	if health_bar and character_data and character_data.max_health:
		_cached_max_health = character_data.max_health.calculate(self)
		health_bar.max_value = _cached_max_health
		health_bar.value = max(0, health)

func gain_block(amount : int):
	block += amount
	display_block()

func display_block():
	if block_display and block_label:
		if block > 0:
			block_display.visible = true
			block_label.text = str(block)
		else:
			block_display.visible = false

func die():
	print("Player has died!")

func set_data(data : CharacterData):
	character_data = data

	# Create independent copies of each stat so in-combat changes are temporary
	# and do not bleed back into the permanent character_data values.
	stats.clear()
	for src in character_data.stats:
		# Ensure the source stat has its value calculated before we copy it.
		src.character = self
		if not src._initialised:
			src.get_value()

		var copy := Stat.new()
		copy.stat_type    = src.stat_type
		copy.value_calc   = src.value_calc
		copy.modify_value = src.modify_value
		copy.character    = self
		copy.value        = src.value
		copy._initialised = true   # value is set — skip formula recalc
		copy.stat_modified.connect(_on_stat_modified)
		stats.append(copy)

	Global.enemy_attacks_player.connect(take_hit.bind())

	if character_data.current_health <= 0:
		character_data.current_health = character_data.max_health.calculate(self)
	health             = character_data.current_health
	_cached_max_health = character_data.max_health.calculate(self)
	block = 0

	position_character()
	set_health_bar()
	display_block()

# ─── Permanent upgrade sync ────────────────────────────────────────────────────
# Call this after any permanent stat change (gym, events, etc.).
# Copies character_data stat values into the combat copies and recalculates HP.
func sync_from_data() -> void:
	for i in stats.size():
		if i < character_data.stats.size():
			stats[i].value = character_data.stats[i].value
	recalculate_max_health()

# ─── Max HP delta calculation ─────────────────────────────────────────────────
# Computes the new max HP, adjusts current HP by the same delta (if positive),
# clamps if max dropped below current HP, and refreshes all UI.
func recalculate_max_health() -> void:
	if not character_data or not character_data.max_health:
		return

	var new_max : int = character_data.max_health.calculate(self)
	var delta   : int = new_max - _cached_max_health

	if delta > 0:
		health                        += delta
		character_data.current_health  = health
	elif delta < 0 and health > new_max:
		health                        = new_max
		character_data.current_health = health

	_cached_max_health = new_max
	set_health_bar()
	if run_manager and run_manager.ui_bar:
		run_manager.ui_bar.set_health()

# ─── In-combat temporary stat changes ────────────────────────────────────────
# Fired when a combat copy stat is modified (buffs, conditions, etc.).
# Permanent changes from the gym go through sync_from_data() instead.
func _on_stat_modified(stat_type: Stat.STAT, new_value: int) -> void:
	recalculate_max_health()
	stats_changed.emit()

func collect_item(item : Item):
	if item.item.item_name == "Gold":
		var amount = run_manager.rng.randi_range(item.item.min_amount, item.item.max_amount)
		character_data.gold += amount
		run_manager.ui_bar.set_gold()

func toggle_visible(visible : bool):
	sprite.visible = visible
	health_bar.visible = visible
	if block_display:
		block_display.visible = visible and block > 0

func reset_for_new_wave() -> void:
	block = 0
	display_block()

	if conditions:
		for condition in conditions:
			if condition.has_method("remove_condition"):
				condition.remove_condition(self)
		conditions.clear()

	# Restore all combat stats to their permanent base values,
	# clearing any in-combat temporary buffs/debuffs.
	sync_from_data()

	# Re-apply persistent special effects for this wave.
	if character_data.special_effects and character_data.special_effects.size() > 0:
		for condition in character_data.special_effects:
			var fresh = condition.duplicate(true)
			fresh.apply_condition(self, fresh)

	if run_manager and run_manager.ui_bar:
		run_manager.ui_bar.set_health()
