extends Thingy
class_name NewtonsCradle

## Newton's Cradle -- passive item.
## When the player forces an enemy to move (push or pull), every OTHER enemy
## in the ranges swept through takes damage.

# -- Configuration -------------------------------------------------------------

## Damage dealt to each enemy in the swept ranges.
## Formula can use: swag, guts, bang, hustle, marbles, mojo
@export var damage_calculator: ValueCalculator

# -- Lifecycle -----------------------------------------------------------------

## Called by RunManager at the start of every combat wave.
func setup(p: Character, rm: RangeManager) -> void:
	super(p, rm)

	# Connect to enemies already present when combat starts.
	for enemy in range_manager.get_all_enemies():
		_connect_enemy(enemy)

	# Connect to enemies that spawn mid-combat.
	Global.enemy_spawned.connect(_on_enemy_spawned)


## Called by RunManager when combat ends.
func teardown() -> void:
	if Global.enemy_spawned.is_connected(_on_enemy_spawned):
		Global.enemy_spawned.disconnect(_on_enemy_spawned)

	# Disconnect from every enemy still alive so signals don't leak into the next wave.
	if is_instance_valid(range_manager):
		for enemy in range_manager.get_all_enemies():
			if enemy.enemy_player_moved.is_connected(_on_enemy_moved):
				enemy.enemy_player_moved.disconnect(_on_enemy_moved)

	super()

# -- Signal handlers -----------------------------------------------------------

func _on_enemy_spawned(enemy: Enemy) -> void:
	_connect_enemy(enemy)


func _on_enemy_moved(enemy: Enemy, old_range: int, new_range: int) -> void:
	# Combat may have ended while this signal was in-flight -- bail silently.
	# Use is_instance_valid so a freed (but non-null) RangeManager is also caught.
	if not is_instance_valid(range_manager):
		return

	var damage := _calculate_damage()
	if damage <= 0:
		return

	# Sweep through every range slot between old and new position (inclusive).
	# min/max ensures this works correctly for both pushes and pulls.
	for r in range(min(old_range, new_range), max(old_range, new_range) + 1):
		for target in range_manager.get_enemies_at_range(r):
			# Don't damage the enemy that was moved.
			if target == enemy:
				continue
			if not target.is_alive():
				continue
			target.take_damgage(damage)

# -- Helpers -------------------------------------------------------------------

func _connect_enemy(enemy: Enemy) -> void:
	if not enemy.enemy_player_moved.is_connected(_on_enemy_moved):
		enemy.enemy_player_moved.connect(_on_enemy_moved)


func _calculate_damage() -> int:
	if damage_calculator and player:
		return damage_calculator.calculate(player)
	return 0


func get_description_with_values() -> String:
	if not damage_calculator or not player:
		return "Forcing an enemy to move deals damage to every enemy it passes through."
	var dmg := damage_calculator.calculate(player)
	var formula := _format_formula_display(damage_calculator.formula)
	return "Forcing an enemy to move deals §%d§ (%s) damage to every enemy in its path." % [dmg, formula]


func _format_formula_display(f: String) -> String:
	return f.replace("*", " x ").replace("/", " / ").replace("+", " + ").replace("-", " - ")
