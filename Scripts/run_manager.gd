extends Node2D
class_name RunManager

## Emitted when this run ends (win or loss), right before RunManager frees
## itself. The session coordinator (Game autoload) listens to decide what
## comes next. RunManager itself never knows about title screens, character
## select, settings, etc. -- it handles exactly one run and then disappears.
signal run_finished(won: bool)

# ──────────────────────────────────────────────────────────────────────────
#  INSPECTOR CONFIG  (grouped for tidiness; groups are purely cosmetic)
# ──────────────────────────────────────────────────────────────────────────

@export_group("Run Setup")
## The player's starting deck. Deep-copied at run start.
@export var deck : Array[CardData]

@export_group("Acts")
## One HordePool per act (index 0 = Act 1, etc.). Each pool defines that act's
## normal fights (recipes) AND its possible bosses (boss_recipes).
@export var act_recipe_pools : Array[HordePool] = []
## Event pool, shared across all acts.
@export var available_events : Array[EventData] = []

@export_group("Scenes")
@export var map_generator_scene : PackedScene
@export var character_sheet_scene : PackedScene
@export var defeat_screen_scene : PackedScene
@export var victory_screen_scene : PackedScene

# ──────────────────────────────────────────────────────────────────────────
#  RUNTIME STATE  (not inspector-assigned)
# ──────────────────────────────────────────────────────────────────────────

var run_seed : int
var rng : RandomNumberGenerator

## Map generation uses its own RNG, re-seeded per act from run_seed so each act's
## layout is visibly different yet a given run_seed stays fully reproducible.
## Keeping it separate from `rng` means reseeding it never disturbs horde, boss,
## or event rolls.
var map_rng : RandomNumberGenerator = RandomNumberGenerator.new()

## The run's character. Set at runtime by Game.start_run and deep-copied in
## begin_run -- NOT assigned in the Inspector, so it's a plain var, not @export.
var character : CharacterData

var card_handler : CardHandler
var player : Character
var draft_amount : int = 3

## Relative weights for normal card-reward drafts, keyed by CardData.RARITY.
## Higher = shows up more often. Rares are deliberately scarce. Boss drafts
## ignore these and offer Rares only (see get_random_card_data's only_rarity).
@export var rarity_weights : Dictionary = {
	CardData.RARITY.Common: 70,
	CardData.RARITY.Uncommon: 25,
	CardData.RARITY.Rare: 5,
}

var range_manager : RangeManager
var ui_bar : UIBar
var current_character_sheet : PopupPanel = null

## Which act the player is on (0-indexed internally, displayed as 1-indexed).
var current_act : int = 0

## Tracks horde recipe_names / event paths used this act so they aren't repeated.
var _used_horde_names : Array[String] = []
var _used_event_names : Array[String] = []

## Runtime fallback enemy list, set by event combats (event.gd) to inject a
## specific fight; consumed by _pick_horde_for_combat. Not inspector-assigned,
## so it's a plain var rather than an export.
var horde : Array[EnemyData] = []

## Set by an event option that triggers combat (event.gd → queue_event_combat).
## When non-null, _on_event_completed launches THIS fight instead of returning to
## the map, and _pick_horde_for_combat forces this exact Horde over the act pool.
var _pending_event_horde : Horde = null
## Opening-noise scalar for an event combat (the modern stand-in for the old
## enemy-count modifier). 1.0 = the horde's own starting noise.
var _pending_event_difficulty : float = 1.0
## Optional win-condition override for an event combat; when null the horde's own
## win_con is used.
var _pending_event_win_con : WinCondition = null

## The Horde selected for the current/most recent combat. Used by RewardScene.
var current_horde : Horde = null

## The boss chosen for the CURRENT act, decided once at map generation with the
## seeded RNG so it's fixed and knowable the moment the map exists. Read by
## begin_boss_combat; nothing re-rolls it.
var current_boss : Horde = null

var current_win_condition : WinCondition = null
var current_event_scene : EventScene = null

var current_draft_screen : DraftScreen = null
var current_reward_scene : RewardScene = null
var current_shop : Shop = null
var current_gym : Gym = null
var current_hospital : Hospital = null
var current_services : Services = null
var current_workshop : Workshop = null

var map_generator : MapGenerator = null
## The node the player most recently selected -- resolved after combat/event ends.
var _pending_map_node : MapNode = null

var current_end_screen : Node = null

enum GameState { MAP, EVENT, COMBAT }
var current_state : GameState = GameState.MAP

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

	# Work on a disposable DEEP COPY of the character so permanent changes this
	# run (stat boosts from gym/Montage, gold spent, thingies bought into
	# special_effects) never bleed back into the saved CharacterData asset.
	# Without this, the cached .tres is mutated and persists across runs.
	if character:
		character = character.duplicate(true)
		# Use the character's signature starting deck if it defines one; otherwise
		# fall back to RunManager's @export deck (shared/legacy default). The
		# deep-duplication loop below makes the cards run-local either way.
		if not character.starting_deck.is_empty():
			deck = character.starting_deck.duplicate()
	else:
		push_error("RunManager: begin_run called but character is null!")

	current_act = 0
	_used_horde_names.clear()
	_used_event_names.clear()
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

	# Wire up run-level listeners for any starting passives the character owns
	# (e.g. a Training Montage given as a build-defining starter). Mid-run
	# pickups are activated in add_thingy_condition instead.
	for fx in character.special_effects:
		if fx.has_method("activate"):
			fx.activate(self)

	# Telemetry: a run is starting. Emitting here makes run_started the first
	# event logged, so everything after it is attributed to this run.
	Global.run_started.emit(character.character_name if character else "", run_seed)

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
			_choose_act_boss()
			_seed_map_for_act()
			map_generator.build(map_rng)
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
		MapNode.NodeType.BOSS:
			Transitions.transition_style = Transitions.TransitionStyle.BROKEN_GLASS
			await Transitions.transition(func(): begin_boss_combat())
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

	# Prefer events not yet seen this act, falling back to all matching only
	# when every option has already been used -- mirrors the horde dedup logic.
	var candidate_pool : Array[EventData] = matching if not matching.is_empty() \
												else available_events
	var fresh_events : Array[EventData] = []
	for ev in candidate_pool:
		if ev.resource_path not in _used_event_names:
			fresh_events.append(ev)
	var chosen_event : EventData = (fresh_events if not fresh_events.is_empty() \
									else candidate_pool).pick_random()

	if chosen_event.resource_path != "" and chosen_event.resource_path not in _used_event_names:
		_used_event_names.append(chosen_event.resource_path)

	current_event_scene = load("res://Scenes/event_scene.tscn").instantiate()
	current_event_scene.run_manager = self
	current_event_scene.current_event = chosen_event
	add_child(current_event_scene)
	current_event_scene.event_completed.connect(_on_event_completed)

func _on_event_completed():
	current_event_scene = null

	# An event option chose to trigger combat: launch that fight instead of
	# resolving the node back to the map. The event's map node stays pending so
	# it's marked visited when the combat is won, exactly like a combat node.
	if _pending_event_horde != null:
		Transitions.transition_style = Transitions.TransitionStyle.BROKEN_GLASS
		await Transitions.transition(func(): begin_combat())
		return

	_resolve_pending_node()


## Called by EventScene when a combat-triggering option resolves. Stores the
## fight to run; the combat actually starts once the event scene finishes and
## _on_event_completed runs. difficulty scales the opening noise; win_con (when
## set) overrides the horde's own win condition.
func queue_event_combat(combat_horde: Horde, difficulty: float = 1.0, win_con: WinCondition = null) -> void:
	_pending_event_horde = combat_horde
	_pending_event_difficulty = maxf(0.1, difficulty)
	_pending_event_win_con = win_con

# ------------------------------------------------------------------------------
#  COMBAT
# ------------------------------------------------------------------------------

func begin_combat():
	current_state = GameState.COMBAT
	begin_wave()

func begin_boss_combat():
	current_state = GameState.COMBAT

	# Use the boss chosen at map generation (see _choose_act_boss).
	var boss_horde : Horde = current_boss

	if boss_horde == null:
		push_error("RunManager: no boss chosen for act %d (boss_recipes empty?)" % (current_act + 1))
		return

	current_horde = boss_horde

	# Split the horde into the boss (first elite) and the minion noise pool.
	var boss_data   : EnemyData          = null
	var minion_pool : Array[EnemyData]   = []
	for ed in boss_horde.get_spawn_pool():
		if ed.is_elite and boss_data == null:
			boss_data = ed       # first elite is the boss
		else:
			minion_pool.append(ed)

	if boss_data == null:
		push_error("RunManager: boss horde for act %d has no elite enemy!" % (current_act + 1))
		return

	# Build the range manager with the minion pool and normal card-driven noise.
	range_manager = load("res://Scenes/range_manager.tscn").instantiate()
	range_manager.run_manager = self
	range_manager.enemy_pool.append_array(minion_pool)
	range_manager.noise_cost_map = boss_horde.get_noise_costs()
	range_manager.starting_noise = boss_horde.starting_noise
	add_child(range_manager)

	if not player:
		create_player()
	player.position_character()
	player.toggle_visible(true)
	player.reset_for_new_wave()

	create_card_handler()
	ui_bar.set_health()

	# Spawn the boss. Because is_elite = true, range_manager._on_elite_spawned()
	# fires automatically and wires up DefeatSingleEnemy + the announcement.
	range_manager.spawn_enemy(boss_data, 5)

	# Telemetry: a boss fight is starting. The win condition is wired by the
	# range manager on elite spawn, so read it off the horde resource if set.
	Global.fight_started.emit(
		current_horde.recipe_name if current_horde else "",
		"boss",
		current_horde.win_con.get_announcement_text() if current_horde and current_horde.win_con else "")

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

	# Telemetry: a normal fight is fully set up (horde + win condition known).
	Global.fight_started.emit(
		current_horde.recipe_name if current_horde else "",
		"normal",
		current_win_condition.get_announcement_text() if current_win_condition else "")

func setup_win_condition():
	var wc_source : WinCondition = current_horde.win_con if current_horde else null

	# An event option can override the horde's own win condition. Consumed once.
	if _pending_event_win_con:
		wc_source = _pending_event_win_con
		_pending_event_win_con = null

	if wc_source:
		current_win_condition = wc_source.duplicate(true)
		current_win_condition.initialize(self)

		if ui_bar and ui_bar.has_method("set_win_condition"):
			ui_bar.set_win_condition(current_win_condition)

		if range_manager and range_manager.has_method("set_win_condition"):
			range_manager.set_win_condition(current_win_condition)

		var announcer := CombatAnnouncer.new()
		announcer.run_manager = self
		add_child(announcer)
		var subtitle := "Act %d" % (current_act + 1)
		announcer.show_announcement(current_win_condition.get_announcement_text(), subtitle)
	else:
		push_warning("No win condition set! Combat will not have a win condition.")

func _on_card_played(card_data: CardData):
	if card_data and range_manager:
		range_manager.process_card_cost(card_data.card_cost)

func create_range_manager():
	range_manager = load("res://Scenes/range_manager.tscn").instantiate()
	range_manager.run_manager = self
	# Populate the pool and set noise BEFORE add_child so _ready() fires
	# with everything in place. The deferred drain in _ready() then handles
	# the first wave of spawns through the noise system.
	range_manager.enemy_pool.append_array(_pick_horde_for_combat())
	range_manager.noise_cost_map = current_horde.get_noise_costs() if current_horde else {}
	range_manager.starting_noise = (current_horde.starting_noise if current_horde else 0.0) * _pending_event_difficulty
	add_child(range_manager)

## Selects enemies from a Horde in the current act's pool that is valid for
## the current map column. Hordes already fought this act are avoided unless
## there are no other column-valid options. Falls back to the legacy horde array if needed.
## Also stores the chosen Horde resource in current_horde for use by RewardScene.
func _pick_horde_for_combat() -> Array[EnemyData]:
	# Event-injected combat forces a specific Horde, bypassing the act pool.
	# current_horde is set to it so noise costs, rewards, and win condition all
	# flow through the normal paths. Consumed once here.
	if _pending_event_horde != null:
		current_horde = _pending_event_horde
		_pending_event_horde = null
		return current_horde.get_spawn_pool()

	var col : int = _pending_map_node.col if _pending_map_node else 0

	if current_act < act_recipe_pools.size():
		var pool : HordePool = act_recipe_pools[current_act]
		if pool:
			var recipe := pool.pick_random(rng, col, _used_horde_names)
			if recipe:
				var pool_enemies := recipe.get_spawn_pool()
				if not pool_enemies.is_empty():
					print("RunManager: act %d col %d using horde '%s'" % [current_act + 1, col, recipe.recipe_name])
					if recipe.recipe_name not in _used_horde_names:
						_used_horde_names.append(recipe.recipe_name)
					current_horde = recipe
					return pool_enemies

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

	# Deal the opening hand so the player can act on turn 1 — block, attack,
	# position — BEFORE any enemy moves. Enemies only act when the player ends
	# the turn (pass_time), so without this you'd end an empty first turn and
	# take the first hit (e.g. the Audit's sniper) straight to HP before ever
	# drawing a card.
	card_handler.draw_multiple_cards(card_handler.cards_to_draw)

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

	# Event-combat overrides are per-fight; clear them so a later normal combat
	# isn't affected. (_pending_event_horde is normally consumed in
	# _pick_horde_for_combat, but reset here too in case combat ended early.)
	_pending_event_horde = null
	_pending_event_difficulty = 1.0
	_pending_event_win_con = null

	# Strip the player's temporary combat buffs (block, conditions, in-combat
	# stat changes) NOW, while range_manager is still alive in case a condition's
	# removal reads from it. Doing this here — before create_reward_scene() — is
	# what keeps the post-combat draft cards showing BASE values instead of the
	# buffed numbers left over from the fight. (reset_for_new_wave still clears
	# state again at the next combat's start; this is harmless overlap.)
	if player and player.has_method("clear_combat_modifiers"):
		player.clear_combat_modifiers()

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
	Transitions.transition_style = Transitions.TransitionStyle.FADE
	await Transitions.transition(func(): _show_map())

func on_combat_won():
	# Telemetry: the fight was won. Emit before teardown clears combat state.
	Global.fight_ended.emit(true)

	## Check before _teardown_combat clears _pending_map_node.
	var was_boss := _pending_map_node != null \
					and _pending_map_node.node_type == MapNode.NodeType.BOSS
	_teardown_combat()

	# Reward scene (gold / card draft / thingy). Boss wins get a Rare-only draft.
	create_reward_scene(was_boss)
	await current_reward_scene.reward_scene_completed

	if was_boss:
		# Boss defeated: advance to the next act (which builds & shows its own
		# fresh map behind a fade), or win the run if this was the final act.
		if current_act + 1 >= act_recipe_pools.size():
			on_run_won()
		else:
			_start_new_act()
		return

	# Normal wave: fade back to the SAME map. No regeneration here — that only
	# happens after a boss (in _start_new_act). Fade replaces the old glass-break
	# that used to play over the map.
	Transitions.transition_style = Transitions.TransitionStyle.FADE
	await Transitions.transition(func(): _show_map())

## Increments the act counter and generates a brand-new map for the next act.
func _start_new_act() -> void:
	current_act += 1
	_used_horde_names.clear()
	_used_event_names.clear()
	print("RunManager: beginning Act %d" % (current_act + 1))
	_choose_act_boss()
	if map_generator:
		# Build AND reveal the next act's map behind a fade. (Boss-win flow no
		# longer shows the old map first, so this path must show it itself.)
		# Re-seed per act so the new act's layout differs from the previous one.
		_seed_map_for_act()
		Transitions.transition_style = Transitions.TransitionStyle.FADE
		await Transitions.transition(func():
			map_generator.build(map_rng)
			current_state = GameState.MAP
			map_generator.show())
	else:
		push_error("RunManager: _start_new_act called but map_generator is null")

## Re-seeds the map RNG from run_seed + the current act, so each act produces a
## distinct-but-reproducible layout. Called immediately before every build.
func _seed_map_for_act() -> void:
	map_rng.seed = run_seed + (current_act + 1) * 1000003

## Picks this act's boss from its HordePool.boss_recipes using the seeded RNG,
## and stores it in current_boss. Called once whenever an act's map is built, so
## the boss is fixed and knowable from map generation onward.
func _choose_act_boss() -> void:
	current_boss = null
	if current_act < act_recipe_pools.size():
		var pool : HordePool = act_recipe_pools[current_act]
		if pool:
			current_boss = pool.pick_boss(rng)
	if current_boss == null:
		push_error("RunManager: no boss available for act %d -- is boss_recipes empty on its HordePool?" % (current_act + 1))
	else:
		print("RunManager: act %d boss will be '%s'" % [current_act + 1, current_boss.recipe_name])

# ------------------------------------------------------------------------------
#  RUN TERMINAL STATES  (victory / defeat)
# ------------------------------------------------------------------------------

## Called from character.die() when the player's health hits 0.
func on_player_death():
	# Telemetry: the fight was lost, which also ends the run. Emit both now so
	# they flush immediately, even if the player quits from the end screen.
	Global.fight_ended.emit(false)
	Global.run_ended.emit(false)

	if current_win_condition:
		current_win_condition.cleanup()
		current_win_condition = null

	print("Game Over!")
	get_tree().paused = true
	_show_end_screen(defeat_screen_scene, "Defeat", false)

## Called from on_combat_won() when the final act's boss is defeated.
func on_run_won():
	# Telemetry: final boss down — the run is won. Emit before the end screen so
	# it's captured even if the player quits without restarting.
	Global.run_ended.emit(true)

	print("Run complete -- victory!")
	get_tree().paused = true
	_show_end_screen(victory_screen_scene, "Victory", true)

## Instantiates an end-screen overlay under the CanvasLayer. The screen runs
## while the tree is paused (PROCESS_MODE_ALWAYS) and should emit
## `restart_requested` when its button is pressed. The `won` flag is forwarded
## to end_run so the coordinator learns the outcome.
func _show_end_screen(scene: PackedScene, label: String, won: bool) -> void:
	if scene == null:
		push_warning("RunManager: %s screen scene not assigned in the inspector." % label)
		return

	if current_end_screen:
		current_end_screen.queue_free()
		current_end_screen = null

	current_end_screen = scene.instantiate()
	current_end_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	$CanvasLayer.add_child(current_end_screen)

	if current_end_screen.has_signal("restart_requested"):
		current_end_screen.restart_requested.connect(end_run.bind(won))
	if "run_manager" in current_end_screen:
		current_end_screen.run_manager = self

## Ends this run. RunManager's only job here is to announce the result and
## remove itself; deciding what happens next belongs to the coordinator
## listening on run_finished. Safe to call from a paused end screen.
## Deactivates run-level thingy listeners first so they don't leak across runs.
func end_run(won: bool) -> void:
	get_tree().paused = false
	if character:
		for fx in character.special_effects:
			if fx.has_method("deactivate"):
				fx.deactivate()
	run_finished.emit(won)
	queue_free()

# ------------------------------------------------------------------------------
#  CARDS — deck additions
# ------------------------------------------------------------------------------

## The single path for adding a card to the run deck. Routes every source
## (shop purchase, reward draft, pickup effects) through here so that
## deck-add listeners (e.g. the Training Montage thingy) fire reliably.
## Appends a fresh deep copy so each deck slot is an independent object.
func add_card_to_deck(card_data : CardData) -> void:
	if card_data == null:
		return
	var copy : CardData = card_data.duplicate(true)
	deck.append(copy)
	Global.card_added_to_deck.emit(copy)

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
## on_pickup() fires once here for one-time acquisition effects (stat grants,
## deck changes). activate() fires here too, to wire up any run-level listeners
## (the same call begin_run makes for starting passives).
func add_thingy_condition(condition: ThingyCondition) -> void:
	# Track the resource path so get_unique_thingy_condition() can exclude it.
	if condition.resource_path != "" and condition.resource_path not in _owned_thingy_paths:
		_owned_thingy_paths.append(condition.resource_path)

	character.special_effects.append(condition)

	# One-time acquisition effect, then wire up run-level listeners.
	condition.on_pickup(self)
	condition.activate(self)

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

func create_draft_screen(only_rarity : int = -1):
	if current_draft_screen:
		current_draft_screen.queue_free()

	var draft_screen_scene = load("res://Scenes/draft_screen.tscn")
	if not draft_screen_scene:
		push_error("Could not load draft_screen.tscn")
		return

	current_draft_screen = draft_screen_scene.instantiate()
	add_child(current_draft_screen)
	current_draft_screen.display_card_options(self, only_rarity)

func close_draft_screen():
	if current_draft_screen:
		current_draft_screen.queue_free()
		current_draft_screen = null

# ------------------------------------------------------------------------------
#  REWARD SCENE
# ------------------------------------------------------------------------------

func create_reward_scene(boss_reward : bool = false) -> void:
	if current_reward_scene:
		current_reward_scene.queue_free()

	current_reward_scene = load("res://Scenes/reward_scene.tscn").instantiate()
	current_reward_scene.run = self
	current_reward_scene.current_horde = current_horde
	current_reward_scene.boss_reward = boss_reward
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
	current_services = load("res://Scenes/services.tscn").instantiate()
	add_child(current_services)
	current_services.service_chosen.connect(_on_service_chosen)
	current_services.display_services(self)

## Frees the chooser without resolving the map node.
func _free_services() -> void:
	if current_services:
		current_services.queue_free()
		current_services = null

## Called when the player leaves Services without picking anything.
## Declining is a valid choice (e.g. full HP, nothing to retune), so the node
## resolves and the run continues.
func close_services() -> void:
	_free_services()
	_resolve_pending_node()

func _on_service_chosen(service: String) -> void:
	# Free the chooser but DON'T resolve yet — the sub-screen we open will
	# resolve the node when it closes.
	_free_services()
	match service:
		"hospital":
			create_hospital()
		"workshop":
			create_workshop()
		"gym":
			create_gym()
		"shop":
			create_shop()
		_:
			push_warning("RunManager: unknown service '%s'" % service)
			_resolve_pending_node()

# ------------------------------------------------------------------------------
#  WORKSHOP  (card re-stat bench — screen not built yet)
# ------------------------------------------------------------------------------

func create_workshop() -> void:
	if current_workshop:
		current_workshop.queue_free()
	current_workshop = Workshop.new()
	add_child(current_workshop)
	current_workshop.workshop_closed.connect(close_workshop)
	current_workshop.display_workshop(self)

func close_workshop() -> void:
	if current_workshop:
		current_workshop.queue_free()
		current_workshop = null
	_resolve_pending_node()

# ------------------------------------------------------------------------------
#  CARDS — random card lookup
# ------------------------------------------------------------------------------

func get_random_card_data(excluded_paths: Array[String] = [], only_rarity : int = -1) -> CardData:
	var dir := DirAccess.open("res://Cards/")
	if dir == null:
		push_error("Could not open Cards directory")
		return null

	# Gather candidate cards (loaded so we can read rarity). Godot caches loads,
	# so re-scanning per draft pick is cheap.
	var candidates : Array[CardData] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Cards/" + file_name
			if path not in excluded_paths:
				var c : CardData = load(path)
				if c and (only_rarity < 0 or c.rarity == only_rarity):
					candidates.append(c)
		file_name = dir.get_next()
	dir.list_dir_end()

	if candidates.is_empty():
		# A forced-rarity draft with no cards of that rarity falls back to any
		# rarity rather than handing the player nothing.
		if only_rarity >= 0:
			push_warning("No cards of rarity %d available; falling back to any rarity." % only_rarity)
			return get_random_card_data(excluded_paths, -1)
		push_error("No CardData files found in Cards directory")
		return null

	# Forced rarity (e.g. boss rewards): uniform pick within that tier.
	if only_rarity >= 0:
		return candidates[randi() % candidates.size()]

	# Normal draft: weight by rarity so Rares surface far less often.
	var weights : Array[float] = []
	var total := 0.0
	for c in candidates:
		var w : float = float(rarity_weights.get(c.rarity, 1))
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates.back()

# ------------------------------------------------------------------------------
#  THINGY CONDITIONS (RESOURCES)
# ------------------------------------------------------------------------------

## Scans res://Thingys/ for .tres files and returns one at random.
## ThingyConditions are Resources, not scenes -- save them as .tres assets.
## An empty / missing folder is an expected dev state, so it warns rather than
## errors; every caller already handles a null return gracefully.
func get_random_thingy_condition(excluded_paths: Array[String] = []) -> ThingyCondition:
	var dir := DirAccess.open("res://Thingys/")
	if dir == null:
		push_warning("RunManager: res://Thingys/ not found yet — no thingies to offer.")
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
		push_warning("RunManager: no ThingyCondition resources in res://Thingys/ (or all excluded).")
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
