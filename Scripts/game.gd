extends Node
## ─────────────────────────────────────────────────────────────────────────────
##  Game — persistent session coordinator (AUTOLOAD)
## ─────────────────────────────────────────────────────────────────────────────
## Lives for the whole session, alongside Global / Animations / Transitions.
## Owns the *flow between* screens: character select -> a single run -> whatever
## comes next. It does NOT touch gameplay. RunManager handles exactly one run
## and removes itself when that run ends; this coordinator decides what happens
## after. Future audio/visual autoloads sit beside this one, not inside it.
##
## SETUP — pick ONE:
##   A) Autoload this as a SCENE (Game.tscn = a single Node with this script)
##      and assign the two PackedScene slots below in the Inspector.
##   B) Autoload the bare script and leave the slots empty -- it will load the
##      scenes from the *_PATH constants instead. If your scene files live
##      elsewhere, just fix the two paths below.

## Optional Inspector overrides (only usable if autoloaded as a SCENE).
@export var character_select_scene : PackedScene
@export var run_manager_scene      : PackedScene

## Fallback paths used when the slots above are empty. Adjust to match your
## project if these don't point at the right files.
const CHARACTER_SELECT_PATH := "res://Scenes/character_select.tscn"
const RUN_MANAGER_PATH      := "res://Scenes/run_manager.tscn"

var _active_screen : Node        = null
var _active_run    : RunManager  = null

## Resolve a scene from the Inspector slot, falling back to a path load.
func _resolve_scene(slot: PackedScene, path: String, what: String) -> PackedScene:
	if slot != null:
		return slot
	var loaded : PackedScene = load(path)
	if loaded == null:
		push_error("Game: '%s' is not assigned and could not be loaded from '%s'." % [what, path])
	return loaded

## Spawn a fresh run for the chosen character. Called by character select.
func start_run(character_data: CharacterData) -> void:
	var scene := _resolve_scene(run_manager_scene, RUN_MANAGER_PATH, "run_manager_scene")
	if scene == null:
		return

	_active_run = scene.instantiate()
	_active_run.character = character_data
	_active_run.run_finished.connect(_on_run_finished)

	get_tree().root.add_child(_active_run)
	get_tree().current_scene = _active_run

	# The character-select screen hands off and frees itself, so drop our ref.
	_active_screen = null

## React to a finished run. RunManager has already removed itself by the time
## this fires -- we only decide what comes next. For now: back to character
## select. Later this is where a results/score/title screen would go, branching
## on `won`.
func _on_run_finished(won: bool) -> void:
	_active_run = null
	show_character_select()

## Instantiate the character-select screen and make it the current scene.
func show_character_select() -> void:
	var scene := _resolve_scene(character_select_scene, CHARACTER_SELECT_PATH, "character_select_scene")
	if scene == null:
		return

	_active_screen = scene.instantiate()
	get_tree().root.add_child(_active_screen)
	get_tree().current_scene = _active_screen
