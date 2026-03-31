extends PopupPanel


enum DisplayMode { BASE_STATS, COMBAT_STATS }
var display_mode : DisplayMode = DisplayMode.BASE_STATS


var character_data : CharacterData  
var character_instance : Character 


@onready var character_image = $VBoxContainer/HBoxContainer/TextureRect
@onready var health_bar = $VBoxContainer/HBoxContainer/Control/TextureProgressBar
@onready var hp_formula_label = $VBoxContainer/HBoxContainer/Control/hp_formula_label
@onready var swag_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/guts_label
@onready var guts_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/guts_label
@onready var marbles_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer3/guts_label
@onready var hustle_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer4/hustle_label
@onready var bang_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer5/bang_label
@onready var mojo_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer6/mojo_label
@onready var effects_label = $VBoxContainer/VBoxContainer/Label2

var _effects_container : HFlowContainer

func _ready():
	# Hide the scene label and replace it with a flow container of ConditionIcons.
	effects_label.visible = false
	_effects_container = HFlowContainer.new()
	_effects_container.add_theme_constant_override("h_separation", 4)
	_effects_container.add_theme_constant_override("v_separation", 4)
	effects_label.get_parent().add_child(_effects_container)

func setup_base_stats(data: CharacterData):
	display_mode = DisplayMode.BASE_STATS
	character_data = data
	populate_character_sheet()

func setup_combat_stats(character: Character):
	display_mode = DisplayMode.COMBAT_STATS
	character_instance = character
	character_data = character.character_data

	if not character_instance.stats_changed.is_connected(refresh):
		character_instance.stats_changed.connect(refresh)
	
	populate_character_sheet()

func populate_character_sheet():
	if not character_data:
		return

	if character_data.character_image:
		character_image.texture = character_data.character_image

	update_health_bar()
	update_stats()
	update_effects()

func update_health_bar():
	if not character_data:
		return
	
	match display_mode:
		DisplayMode.BASE_STATS:
			var max_hp = _calculate_base_max_health()
			var current_hp = character_data.current_health
			health_bar.max_value = max_hp
			health_bar.value = current_hp
			
		DisplayMode.COMBAT_STATS:
			if character_instance:
				health_bar.max_value = character_data.max_health.calculate(character_instance)
				health_bar.value = character_instance.health

	if hp_formula_label and character_data.max_health and character_data.max_health.formula != "":
		hp_formula_label.text = "( %s )" % character_data.max_health.formula
	elif hp_formula_label:
		hp_formula_label.text = ""

func _calculate_base_max_health() -> int:
	if character_instance:
		return character_data.max_health.calculate(character_instance)
	else:
		return character_data.max_health.calculate(null) if character_data.max_health else 100

func update_stats():
	if not character_data:
		return
	
	match display_mode:
		DisplayMode.BASE_STATS:
			_update_base_stats()
		DisplayMode.COMBAT_STATS:
			_update_combat_stats()

func _update_base_stats():
	if not character_data.stats:
		return
	
	for stat in character_data.stats:
		var base_value = stat.value
		match stat.stat_type:
			Stat.STAT.SWAG:
				swag_label.text = str(base_value)
			Stat.STAT.GUTS:
				guts_label.text = str(base_value)
			Stat.STAT.MARBLES:
				marbles_label.text = str(base_value)
			Stat.STAT.HUSTLE:
				hustle_label.text = str(base_value)
			Stat.STAT.BANG:
				bang_label.text = str(base_value)
			Stat.STAT.MOJO:
				mojo_label.text = str(base_value)

func _update_combat_stats():
	if not character_instance or not character_instance.stats:
		return
	
	for stat in character_instance.stats:
		var current_value = stat.value
		var display_text = str(current_value)
		
		if "base_value" in stat and stat.value != stat.base_value:
			display_text = "%d (%d)" % [current_value, stat.base_value]
		
		match stat.stat_type:
			Stat.STAT.SWAG:
				swag_label.text = display_text
			Stat.STAT.GUTS:
				guts_label.text = display_text
			Stat.STAT.MARBLES:
				marbles_label.text = display_text
			Stat.STAT.HUSTLE:
				hustle_label.text = display_text
			Stat.STAT.BANG:
				bang_label.text = display_text
			Stat.STAT.MOJO:
				mojo_label.text = display_text

func update_effects():
	if not _effects_container:
		return

	for child in _effects_container.get_children():
		child.queue_free()

	if not character_data or character_data.special_effects.is_empty():
		return

	for effect in character_data.special_effects:
		if effect is Condition:
			var icon := ConditionIcon.new()
			icon.set_condition(effect)
			_effects_container.add_child(icon)
			icon.ready.connect(icon.update_display.bind(), CONNECT_ONE_SHOT)

func refresh():
	populate_character_sheet()

func _exit_tree():
	if character_instance and character_instance.stats_changed.is_connected(refresh):
		character_instance.stats_changed.disconnect(refresh)
