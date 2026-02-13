extends Node2D
class_name RunManager

########
var run_seed : int
var rng : RandomNumberGenerator

var card_handler : CardHandler 
var player : Character
var draft_amount : int = 3
@export var deck : Array[CardData]
var range_manager : RangeManager 
var ui_bar : UIBar
@export var character : CharacterData


@export var character_sheet_scene : PackedScene  
var current_character_sheet : PopupPanel = null


@export var initial_enemy_count : int = 3
@export var initial_spawn_range : int = 5
@export var horde : Array[EnemyData]


@export var win_condition: WinCondition  
var current_win_condition: WinCondition = null


@export var available_events: Array[EventData] = []  
var current_event_scene: EventScene = null


var current_draft_screen: DraftScreen = null


enum GameState { EVENT, COMBAT }
var current_state: GameState = GameState.EVENT

func begin_run(seed : int = -1):
	rng = RandomNumberGenerator.new()
	if seed == -1:
		run_seed = randi()
	else: 
		run_seed = seed
	rng.seed = run_seed
	create_ui()
	
	
	create_player()
	player.toggle_visible(false)  

func _ready() -> void:
	begin_run()
	Global.card_played.connect(_on_card_played)
	
	
	show_random_event()

func show_random_event():
	if available_events.is_empty():
		push_warning("No events available - starting combat directly")
		begin_combat()
		return
	
	current_state = GameState.EVENT
	
	
	var event = available_events.pick_random()
	
	
	current_event_scene = load("res://Scenes/event_scene.tscn").instantiate()
	current_event_scene.run_manager = self
	current_event_scene.current_event = event
	add_child(current_event_scene)
	
	
	current_event_scene.event_completed.connect(_on_event_completed)

func _on_event_completed():
	current_event_scene = null
	begin_combat()

func begin_combat():
	current_state = GameState.COMBAT
	begin_wave()

func begin_wave():
	create_range_manager()    
	
	
	if player:
		player.toggle_visible(true)
		player.reset_for_new_wave()  
	else:
		
		create_player()
		player.toggle_visible(true)
		
	create_card_handler()
	ui_bar.set_health()
	

	setup_win_condition()

func setup_win_condition():
	"""Initialize the win condition for this combat"""
	if win_condition:
		current_win_condition = win_condition.duplicate(true)
		current_win_condition.initialize(self)
		
		if ui_bar and ui_bar.has_method("set_win_condition"):
			ui_bar.set_win_condition(current_win_condition)
	else:
		push_warning("No win condition set! Combat will not have a win condition.")

func spawn_initial_enemies():
	"""
	Only spawn initial enemies if the win condition doesn't handle spawning itself.
	For example, DefeatAllEnemies spawns its own wave.
	"""
	
	if current_win_condition is DefeatAllEnemies:
		return
	
	if current_win_condition is SurviveXTurns:
		pass
	
	if range_manager.enemy_pool.is_empty():
		push_warning("No enemies in enemy_pool - cannot spawn initial enemies")
		return
	
	for i in initial_enemy_count:
		var random_enemy = range_manager.enemy_pool.pick_random()
		range_manager.spawn_enemy(random_enemy, initial_spawn_range)

func _on_card_played(card_data: CardData):
	if card_data and range_manager:
		range_manager.process_card_cost(card_data.card_cost)

func create_range_manager():
	range_manager = RangeManager.new()
	add_child(range_manager)
	range_manager.run_manager = self
	range_manager.enemy_pool.append_array(horde) 
	spawn_initial_enemies()

func create_card_handler():
	card_handler = load("res://Scenes/card_handler.tscn").instantiate()
	add_child(card_handler)
	card_handler.run_manager = self
	card_handler.initialize()
	
	for card in deck:
		card_handler.create_card(card)
	card_handler.draw_stack.shuffle()

func create_player():
	player = load("res://Scenes/character.tscn").instantiate()
	add_child(player)
	player.run_manager = self  
	player.set_data(character)

func create_ui():
	var ui : UIBar = load("res://Scenes/ui_bar.tscn").instantiate()
	ui.run_manager = self
	add_child(ui)
	ui_bar = ui
	ui.set_gold()
	ui.set_health()
# ===== CHARACTER SHEET METHODS =====

func show_base_character_sheet():
	"""
	Shows the character sheet with BASE stats (unmodified).
	Call this from events or outside of combat.
	"""
	if not character_sheet_scene:
		push_error("Character sheet scene not assigned! Assign it in the RunManager inspector.")
		return
	
	
	if current_character_sheet:
		current_character_sheet.queue_free()
	
	
	current_character_sheet = character_sheet_scene.instantiate()
	add_child(current_character_sheet)
	
	
	current_character_sheet.popup_hide.connect(_on_character_sheet_closed)
	
	
	current_character_sheet.setup_base_stats(character)
	
	
	current_character_sheet.popup_centered()
	
	return current_character_sheet

func show_combat_character_sheet():
	"""
	Shows the character sheet with LIVE combat stats (including modifications).
	Call this during combat to see current buffed/debuffed stats.
	"""
	if not character_sheet_scene:
		push_error("Character sheet scene not assigned! Assign it in the RunManager inspector.")
		return
	
	if not player:
		push_error("Cannot show combat character sheet - no player instance exists!")
		return
	
	
	if current_character_sheet:
		current_character_sheet.queue_free()
	
	
	current_character_sheet = character_sheet_scene.instantiate()
	add_child(current_character_sheet)
	
	
	current_character_sheet.popup_hide.connect(_on_character_sheet_closed)
	
	
	current_character_sheet.setup_combat_stats(player)
	
	
	current_character_sheet.popup_centered()
	
	return current_character_sheet

func close_character_sheet():
	"""Closes the currently open character sheet"""
	if current_character_sheet:
		current_character_sheet.queue_free()
		current_character_sheet = null
		_on_character_sheet_closed()

func _on_character_sheet_closed():
	"""Called when character sheet is closed (either by user or programmatically)"""
	current_character_sheet = null
	
	if ui_bar:
		ui_bar.is_character_sheet_open = false

# ===== END CHARACTER SHEET METHODS =====
	
func on_combat_won():
	if current_win_condition:
		current_win_condition.cleanup()
		current_win_condition = null
	
	if range_manager:
		range_manager.queue_free()
		range_manager = null
	if card_handler:
		card_handler.queue_free()
		card_handler = null
	if player:
		player.toggle_visible(false)
		
	
	
	show_random_event()


func on_player_death():
	if current_win_condition:
		current_win_condition.cleanup()
		current_win_condition = null
	
	
	print("Game Over!")
	
	
func get_random_card_data() -> CardData:
	var dir := DirAccess.open("res://Cards/")
	if dir == null:
		push_error("Could not open Cards directory")
		return null
	var card_paths := []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			card_paths.append("res://Cards/" + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	if card_paths.is_empty():
		push_error("No CardData files found in Cards directory")
		return null

	var random_path = card_paths[randi() % card_paths.size()]
	var new_card : CardData = load(random_path)
	return new_card

# ===== DRAFT SCREEN METHODS =====

func create_draft_screen():
	"""Creates and displays a draft screen with random card options"""
	
	if current_draft_screen:
		current_draft_screen.queue_free()
	
	
	var draft_screen_scene = load("res://Scenes/draft_screen.tscn")
	if not draft_screen_scene:
		push_error("Could not load draft_screen.tscn - make sure the scene exists at res://Scenes/draft_screen.tscn")
		return
	
	current_draft_screen = draft_screen_scene.instantiate()
	add_child(current_draft_screen)
	
	
	current_draft_screen.display_card_options(self)
	


func close_draft_screen():
	"""Closes the currently open draft screen"""
	if current_draft_screen:
		current_draft_screen.queue_free()
		current_draft_screen = null

# ===== END DRAFT SCREEN METHODS =====
