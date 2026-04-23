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

## Which act the player is currently on (0-indexed internally, displayed as 1-indexed).
var current_act : int = 0

## Tracks horde recipe_names fought so far this act so they aren't repeated.
## Reset at run start and whenever a new act begins.
var _used_horde_names : Array[String] = []

## One HordePool per act (index 0 = Act 1, index 1 = Act 2, etc.).
## If the player reaches an act beyond this array, falls back to horde.
@export var act_recipe_pools : Array[HordePool] = []

## Fallback enemy list used when no pool is defined for the current act.
@export var horde : Array[EnemyData] = []

## The Horde resource that was selected for the current (or most recent) combat.
## Populated by _pick_horde_for_combat(); used by the RewardScene.
var current_horde : Horde = null

@export var win_condition: WinCondition
var current_win_condition: WinCondition = null

@export var available_events: Array[EventData] = []
var current_event_scene: EventScene = null

var current_draft_screen: DraftScreen = null
var current_reward_scene: RewardScene = null
var current_shop: Shop = null
var current_gym      : Gym      = null
var current_hospital : Hospital = null
var current_services : Services = null

# -- Map -----------------------------------------------------------------------
## Assign the MapGenerator scene in the inspector.
@export var map_generator_scene : PackedScene
var map_generator : MapGenerator = null
## The node the player most recently selected -- resolved after combat/event ends.
var _pending_map_node : MapNode = null

enum GameState { MAP, EVENT, COMBAT }
var current_state: GameState = GameState.MAP

# -- Thingy dedup --------------------------------------------------------------
## resource_path values of every ThingyCondition the player has acquired this run.
## Used by get_unique_thingy_condition() to avoid duplicates.
var _owned_thingy_paths : Array[String] = []

# ------------------------------------------------------------------------------

func begin_run(seed : int = -1):
	rng = RandomNumberGenerator.new()
	if seed == -1:
		run_seed = randi()
	else:
		run_seed = seed
	rng.seed = run_seed
	current_act = 0
	_used_horde_names.clear()
	_owned_thingy_paths.clear()

	# Deep-duplicate every card so each slot is an independent object.
	# The @export deck array holds .tres resource references which Godot caches,
	# meaning all copies of the same card share one object. Without this,
	# any mutation (adding actions, setting flags, etc.) affects every copy.
	for i in deck.size():
		deck[i] = deck[i].duplicate(true)

	create_ui()
	create_player()
	player.toggle_visible(false)

func _ready() -> void:
	begin_run()
	Global.card_played.connect(_on_card_played)
	_show_map()

# ------------------------------------------------------------------------------
#  MAP
# ------------------------------------------------------------------------------

func _show_map() -> void:
	current_state = GameState.MAP

	if map_generator == null:
		if map_generator_scene:
			map_generator = map_generator_scene.instantiate()
			add_child(map_generator)
			map_generator.node_chosen.connect(_on_map_node_chosen)
			map_generator.build(rng)
		else:
			push_error("RunManager: map_generator_scene is not assigned in the inspector!")
			return
	else:
		map_generator.show()

func _on_map_node_chosen(node: MapNode) -> void:
	_pending_map_node = node
	map_generator.hide()

	match node.node_type:
		MapNode.NodeType.COMBAT:
			Transitions.transition_style = Transitions.TransitionStyle.BROKEN_GLASS
			await Transitions.transition(func(): begin_combat())
		MapNode.NodeType.SHOP:
			Transitions.transition_style = Transitions.TransitionStyle.FADE
			await Transitions.transition(func(): create_shop())
		MapNode.NodeType.GYM:
			Transitions.transition_style = Transitions.TransitionStyle.FADE
			await Transitions.transition(func(): create_gym())
		MapNode.NodeType.SERVICES:
			Transitions.transition_style = Transitions.TransitionStyle.FADE
			await Transitions.transition(func(): create_services())
		MapNode.NodeType.HOSPITAL:
			Transitions.transition_style = Transitions.TransitionStyle.FADE
			await Transitions.transition(func(): create_hospital())
		_:
			await Transitions.transition(func(): _show_event_for_node(node))

# ------------------------------------------------------------------------------
#  EVENTS
# ------------------------------------------------------------------------------

func _show_event_for_node(node: MapNode) -> void:
	if available_events.is_empty():
		push_warning("No events available -- starting combat instead.")
		begin_combat()
		return

	current_state = GameState.EVENT

	var target_exit_type : int = node.node_type - 1

	var matching : Array[EventData] = []
	for ev in available_events:
		if ev.event_type == target_exit_type:
			matching.append(ev)

	var chosen_event : EventData = matching.pick_random() if not matching.is_empty() \
									else available_events.pick_random()

	current_event_scene = load("res://Scenes/event_scene.tscn").instantiate()
	current_event_scene.run_manager = self
	current_event_scene.current_event = chosen_event
	add_child(current_event_scene)
	current_event_scene.event_completed.connect(_on_event_completed)

func _on_event_completed():
	current_event_scene = null
	_resolve_pending_node()

# ------------------------------------------------------------------------------
#  COMBAT
# ------------------------------------------------------------------------------

func begin_combat():
	current_state = GameState.COMBAT
	begin_wave()

func begin_wave():
	create_range_manager()
	player.position_character()

	if player:
		player.toggle_visible(true)
		# reset_for_new_wave tears down last wave's condition instances and
		# re-applies character_data.special_effects (which includes thingy
		# conditions) as fresh duplicates, calling setup() on each one now
		# that a RangeManager is live in the scene tree.
		player.reset_for_new_wave()
	else:
		create_player()
		player.toggle_visible(true)

	create_card_handler()
	ui_bar.set_health()
	setup_win_condition()

func setup_win_condition():
	if win_condition:
		current_win_condition = win_condition.duplicate(true)
		current_win_condition.initialize(self)

		if ui_bar and ui_bar.has_method("set_win_condition"):
			ui_bar.set_win_condition(current_win_condition)

		if range_manager and range_manager.has_method("set_win_condition"):
			range_manager.set_win_condition(current_win_condition)

		# Show the announcement
		var announcer := CombatAnnouncer.new()
		announcer.run_manager = self
		add_child(announcer)
		var subtitle := "Act %d" % (current_act + 1)
		announcer.show_announcement(current_win_condition.get_announcement_text(), subtitle)
	else:
		push_warning("No win condition set! Combat will not have a win condition.")

func spawn_initial_enemies():
	if current_win_condition is DefeatAllEnemies:
		return

	if current_win_condition is SurviveXTurns:
		pass

	if range_manager.enemy_pool.is_empty():
		push_warning("No enemies in enemy_pool -- cannot spawn initial enemies")
		return

	for i in initial_enemy_count:
		var random_enemy = range_manager.enemy_pool.pick_random()
		range_manager.spawn_enemy(random_enemy, initial_spawn_range)

func _on_card_played(card_data: CardData):
	if card_data and range_manager:
		range_manager.process_card_cost(card_data.card_cost)

func create_range_manager():
	range_manager = load("res://Scenes/range_manager.tscn").instantiate()
	add_child(range_manager)
	range_manager.run_manager = self
	range_manager.enemy_pool.append_array(_pick_horde_for_combat())
	spawn_initial_enemies()

## Selects enemies from a Horde in the current act's pool that is valid for
## the current map column. Hordes already fought this act are avoided unless
## there are no other column-valid options. Falls back to the legacy horde array if needed.
## Also stores the chosen Horde resource in current_horde for use by RewardScene.
func _pick_horde_for_combat() -> Array[EnemyData]:
	var col : int = _pending_map_node.col if _pending_map_node else 0

	if current_act < act_recipe_pools.size():
		var pool : HordePool = act_recipe_pools[current_act]
		if pool:
			var recipe := pool.pick_random(rng, col, _used_horde_names)
			if recipe and not recipe.enemies.is_empty():
				print("RunManager: act %d col %d using horde '%s'" % [current_act + 1, col, recipe.recipe_name])
				if recipe.recipe_name not in _used_horde_names:
					_used_horde_names.append(recipe.recipe_name)
				current_horde = recipe
				return recipe.enemies

	# Fallback: no matching pool recipe -- clear current_horde since there's
	# no Horde resource to pull rewards from.
	current_horde = null

	if not horde.is_empty():
		push_warning("RunManager: no pool for act %d, using fallback horde." % (current_act + 1))
		return horde

	push_warning("RunManager: no horde or fallback set for act %d col %d" % [current_act + 1, col])
	return []

func create_card_handler():
	card_handler = load("res://Scenes/card_handler.tscn").instantiate()
	$CanvasLayer.add_child(card_handler)
	
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
	if ui_bar:
		ui_bar.set_health()

func create_ui():
	var ui : UIBar = load("res://Scenes/ui_bar.tscn").instantiate()
	ui.run_manager = self
	add_child(ui)
	ui_bar = ui
	ui.set_gold()

# ------------------------------------------------------------------------------
#  RESOLVE NODE -> RETURN TO MAP
# ------------------------------------------------------------------------------

## Tears down all combat systems and advances the map node.
## Does NOT transition to the map -- callers decide what comes next.
func _teardown_combat() -> void:
	if current_win_condition:
		current_win_condition.cleanup()
		current_win_condition = null

	# Thingy condition teardown happens at the START of the next wave inside
	# reset_for_new_wave, so nothing extra is needed here.

	if range_manager:
		range_manager.queue_free()
		range_manager = null

	if card_handler:
		card_handler.queue_free()
		card_handler = null

	if player:
		player.toggle_visible(false)

	if _pending_map_node and map_generator:
		map_generator.mark_visited_and_advance(_pending_map_node)
		_pending_map_node = null

## Called by _on_event_completed. Tears down and returns to the map.
func _resolve_pending_node() -> void:
	_teardown_combat()
	await Transitions.transition(func(): _show_map())

func on_combat_won():
	## Check before _teardown_combat clears _pending_map_node.
	var was_boss := _pending_map_node != null \
					and _pending_map_node.node_type == MapNode.NodeType.BOSS
	_teardown_combat()

	# Show the reward scene (contains gold / card draft / thingy buttons).
	# The reward scene handles the card draft internally and emits
	# reward_scene_completed when the player clicks Continue.
	create_reward_scene()
	await current_reward_scene.reward_scene_completed

	await Transitions.transition(func(): _show_map())
	if was_boss:
		_start_new_act()

## Increments the act counter and generates a brand-new map for the next act.
func _start_new_act() -> void:
	current_act += 1
	_used_horde_names.clear()
	print("RunManager: beginning Act %d" % (current_act + 1))
	if map_generator:
		await Transitions.transition(func(): map_generator.build(rng))
	else:
		push_error("RunManager: _start_new_act called but map_generator is null")

func on_player_death():
	if current_win_condition:
		current_win_condition.cleanup()
		current_win_condition = null

	print("Game Over!")

# ------------------------------------------------------------------------------
#  THINGY CONDITIONS
# ------------------------------------------------------------------------------

## Add a thingy condition to the run. Call this whenever the player acquires
## a passive item (e.g. from the shop or a reward screen).
##
## The condition is stored in character_data.special_effects so it persists
## across waves. reset_for_new_wave re-applies it as a fresh duplicate at the
## start of every subsequent combat, calling setup() automatically.
##
## If a combat wave is already in progress, a working copy is applied to the
## player immediately so it takes effect without waiting for the next wave.
func add_thingy_condition(condition: ThingyCondition) -> void:
	# Track the resource path so get_unique_thingy_condition() can exclude it.
	if condition.resource_path != "" and condition.resource_path not in _owned_thingy_paths:
		_owned_thingy_paths.append(condition.resource_path)

	character.special_effects.append(condition)

	if current_state == GameState.COMBAT and player:
		var fresh := condition.duplicate(true) as ThingyCondition
		fresh.apply_condition(player, fresh)

## Returns a ThingyCondition the player does not already own.
## Pass extra_excluded to also skip thingies offered elsewhere on the same
## reward screen (prevents two Thingy buttons showing the same item).
func get_unique_thingy_condition(extra_excluded: Array[String] = []) -> ThingyCondition:
	var all_excluded := _owned_thingy_paths.duplicate()
	all_excluded.append_array(extra_excluded)
	return get_random_thingy_condition(all_excluded)

# ------------------------------------------------------------------------------
#  CHARACTER SHEET
# ------------------------------------------------------------------------------

func show_base_character_sheet():
	if not character_sheet_scene:
		push_error("Character sheet scene not assigned!")
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
	if not character_sheet_scene:
		push_error("Character sheet scene not assigned!")
		return

	if not player:
		push_error("Cannot show combat character sheet -- no player instance exists!")
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
	if current_character_sheet:
		current_character_sheet.queue_free()
		current_character_sheet = null
		_on_character_sheet_closed()

func _on_character_sheet_closed():
	current_character_sheet = null

	if ui_bar:
		ui_bar.is_character_sheet_open = false

# ------------------------------------------------------------------------------
#  DRAFT SCREEN
# ------------------------------------------------------------------------------

func create_draft_screen():
	if current_draft_screen:
		current_draft_screen.queue_free()

	var draft_screen_scene = load("res://Scenes/draft_screen.tscn")
	if not draft_screen_scene:
		push_error("Could not load draft_screen.tscn")
		return

	current_draft_screen = draft_screen_scene.instantiate()
	add_child(current_draft_screen)
	current_draft_screen.display_card_options(self)

func close_draft_screen():
	if current_draft_screen:
		current_draft_screen.queue_free()
		current_draft_screen = null

# ------------------------------------------------------------------------------
#  REWARD SCENE
# ------------------------------------------------------------------------------

func create_reward_scene() -> void:
	if current_reward_scene:
		current_reward_scene.queue_free()

	current_reward_scene = load("res://Scenes/reward_scene.tscn").instantiate()
	current_reward_scene.run = self
	current_reward_scene.current_horde = current_horde
	get_tree().root.add_child(current_reward_scene)
	current_reward_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	

func close_reward_scene() -> void:
	if current_reward_scene:
		current_reward_scene.queue_free()
		current_reward_scene = null

# ------------------------------------------------------------------------------
#  SHOP
# ------------------------------------------------------------------------------

func create_shop() -> void:
	if current_shop:
		current_shop.queue_free()

	current_shop = load("res://Scenes/shop.tscn").instantiate()
	add_child(current_shop)
	current_shop.display_shop(self)
	current_shop.shop_closed.connect(_on_shop_closed)

func close_shop() -> void:
	if current_shop:
		current_shop.queue_free()
		current_shop = null
	_resolve_pending_node()

func _on_shop_closed() -> void:
	pass

# ------------------------------------------------------------------------------
#  GYM
# ------------------------------------------------------------------------------

func create_gym() -> void:
	if current_gym:
		current_gym.queue_free()
	current_gym = Gym.new()
	add_child(current_gym)
	current_gym.gym_closed.connect(close_gym)
	current_gym.display_gym(self)

func close_gym() -> void:
	if current_gym:
		current_gym.queue_free()
		current_gym = null
	_resolve_pending_node()

# ------------------------------------------------------------------------------
#  HOSPITAL
# ------------------------------------------------------------------------------

func create_hospital() -> void:
	if current_hospital:
		current_hospital.queue_free()
	current_hospital = Hospital.new()
	add_child(current_hospital)
	current_hospital.hospital_closed.connect(close_hospital)
	current_hospital.display_hospital(self)

func close_hospital() -> void:
	if current_hospital:
		current_hospital.queue_free()
		current_hospital = null
	_resolve_pending_node()

# ------------------------------------------------------------------------------
#  SERVICES
# ------------------------------------------------------------------------------

func create_services() -> void:
	if current_services:
		current_services.queue_free()
	current_services = Services.new()
	add_child(current_services)
	current_services.service_chosen.connect(_on_service_chosen)
	current_services.display_services(self)

func close_services() -> void:
	if current_services:
		current_services.queue_free()
		current_services = null

func _on_service_chosen(service: String) -> void:
	close_services()
	match service:
		"hospital":
			create_hospital()
		"gym":
			create_gym()
		"shop":
			create_shop()
		_:
			push_warning("RunManager: unknown service '%s'" % service)
			_resolve_pending_node()

# ------------------------------------------------------------------------------
#  CARDS
# ------------------------------------------------------------------------------

func get_random_card_data(excluded_paths: Array[String] = []) -> CardData:
	var dir := DirAccess.open("res://Cards/")
	if dir == null:
		push_error("Could not open Cards directory")
		return null
	var card_paths := []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Cards/" + file_name
			if path not in excluded_paths:
				card_paths.append(path)
		file_name = dir.get_next()

	dir.list_dir_end()

	if card_paths.is_empty():
		push_error("No CardData files found in Cards directory")
		return null

	var random_path = card_paths[randi() % card_paths.size()]
	var new_card : CardData = load(random_path)
	return new_card

# ------------------------------------------------------------------------------
#  THINGY CONDITIONS (RESOURCES)
# ------------------------------------------------------------------------------

## Scans res://Thingys/ for .tres files and returns one at random.
## ThingyConditions are Resources, not scenes -- save them as .tres assets.
func get_random_thingy_condition(excluded_paths: Array[String] = []) -> ThingyCondition:
	var dir := DirAccess.open("res://Thingys/")
	if dir == null:
		push_error("RunManager: could not open Thingys directory")
		return null

	var paths : Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Thingys/" + file_name
			if path not in excluded_paths:
				paths.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()

	if paths.is_empty():
		push_error("RunManager: no ThingyCondition resources found in res://Thingys/")
		return null

	return load(paths[randi() % paths.size()])

# ------------------------------------------------------------------------------
#  GOLD
# ------------------------------------------------------------------------------

## Award gold to the player and sync the HUD.
func award_gold(amount: int) -> void:
	character.gold += amount
	if ui_bar:
		ui_bar.set_gold()
