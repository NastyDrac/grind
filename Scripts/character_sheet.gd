extends PopupPanel


enum DisplayMode { BASE_STATS, COMBAT_STATS }
var display_mode : DisplayMode = DisplayMode.BASE_STATS


var character_data : CharacterData  
var character_instance : Character 


@onready var character_image = $VBoxContainer/HBoxContainer/TextureRect
@onready var health_bar = $VBoxContainer/HBoxContainer/Control/TextureProgressBar
@onready var swag_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/guts_label
@onready var guts_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/guts_label
@onready var marbles_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer3/guts_label
@onready var hustle_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer4/hustle_label
@onready var bang_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer5/bang_label
@onready var mojo_label = $VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer6/mojo_label
@onready var effects_label = $VBoxContainer/VBoxContainer/Label2

func _ready():
	pass

func setup_base_stats(data: CharacterData):
	"""Setup to show base character stats (unmodified by combat buffs)"""
	display_mode = DisplayMode.BASE_STATS
	character_data = data
	populate_character_sheet()

func setup_combat_stats(character: Character):
	"""Setup to show live combat stats (with all modifications)"""
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
	"""Updates the health bar based on current and max health"""
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

func _calculate_base_max_health() -> int:
	"""Calculate max health using base stats only"""

	if character_instance:

		return character_data.max_health.calculate(character_instance)
	else:

		var stat_dict = {}
		for stat in character_data.stats:
			stat_dict[stat.stat_type] = stat.value
		
		
		return character_data.max_health.calculate(null) if character_data.max_health else 100

func update_stats():
	"""Updates all stat labels based on display mode"""
	if not character_data:
		return
	
	match display_mode:
		DisplayMode.BASE_STATS:

			_update_base_stats()
		DisplayMode.COMBAT_STATS:

			_update_combat_stats()

func _update_base_stats():
	"""Updates labels with base stat values (unmodified)"""
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
	"""Updates labels with current combat stat values (with modifications)"""
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
	"""Updates the effects text based on special_effects array"""
	if not character_data:
		return
	
	if character_data.special_effects.is_empty():
		effects_label.text = "No special effects"
	else:
		var effects_text = ""
		for effect in character_data.special_effects:
			if effects_text != "":
				effects_text += "\n"
			
			if "description" in effect:
				effects_text += effect.description
			elif "name" in effect:
				effects_text += effect.name
			else:
				effects_text += str(effect)
		effects_label.text = effects_text

func refresh():
	"""Refreshes all displayed data"""
	populate_character_sheet()

func _exit_tree():
	"""Cleanup connections when sheet is removed"""
	if character_instance and character_instance.stats_changed.is_connected(refresh):
		character_instance.stats_changed.disconnect(refresh)
