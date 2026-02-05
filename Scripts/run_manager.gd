extends Node2D
class_name RunManager

########
var run_seed : int
var rng : RandomNumberGenerator

var card_handler : CardHandler 
var player : Character

@export var deck : Array[CardData]
var range_manager : RangeManager 
var ui_bar : UIBar
@export var character : CharacterData

# Initial wave setup
@export var initial_enemy_count : int = 3
@export var initial_spawn_range : int = 5
@export var horde : Array[EnemyData]

# Event system
@export var available_events: Array[EventData] = []  # Pool of events to choose from
var current_event_scene: EventScene = null

# Game state
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

func _ready() -> void:
	begin_run()
	Global.card_played.connect(_on_card_played)
	
	# Start with an event instead of combat
	show_random_event()

func show_random_event():
	if available_events.is_empty():
		push_warning("No events available - starting combat directly")
		begin_combat()
		return
	
	current_state = GameState.EVENT
	
	# Pick a random event
	var event = available_events.pick_random()
	
	# Create and show the event scene
	current_event_scene = load("res://Scenes/event_scene.tscn").instantiate()
	current_event_scene.run_manager = self
	current_event_scene.current_event = event
	add_child(current_event_scene)
	
	# Connect to event completion
	current_event_scene.event_completed.connect(_on_event_completed)

func _on_event_completed():
	current_event_scene = null
	# After event, start combat (the zombie horde blocking the way back to the car)
	begin_combat()

func begin_combat():
	current_state = GameState.COMBAT
	begin_wave()

func begin_wave():
	create_range_manager()    # Create range_manager FIRST
	create_player()           # Then create player - now range_manager exists
	create_card_handler()

func spawn_initial_enemies():
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
	player.run_manager = self  # ADD THIS LINE - set run_manager BEFORE set_data
	player.set_data(character)

func create_ui():
	var ui : UIBar = load("res://Scenes/ui_bar.tscn").instantiate()
	ui.run_manager = self
	add_child(ui)
	ui_bar = ui
# Called when combat is won
func on_combat_won():
	# Clean up combat
	if range_manager:
		range_manager.queue_free()
		range_manager = null
	if card_handler:
		card_handler.queue_free()
		card_handler = null
	if player:
		player.queue_free()
		player = null
	
	# Show next event
	show_random_event()

# Called when player dies
func on_player_death():
	# Handle game over
	print("Game Over!")
	# You'll want to show a game over screen here
