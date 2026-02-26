extends Thingy
class_name NewtonsCradle

## Newton's Cradle — passive item.
## When any enemy is pushed (new_range > old_range), every OTHER enemy
## occupying a range the pushed enemy crossed through or landed on takes damage.
##
## Example: enemy pushed from range 2 → range 5 hits all enemies at ranges 3, 4, and 5.

# ── Configuration ─────────────────────────────────────────────────────────────

## Damage dealt to each enemy in the swept ranges.
## Formula can use: swag, guts, bang, hustle, marbles, mojo
@export var damage_calculator: ValueCalculator

# ── Lifecycle ─────────────────────────────────────────────────────────────────

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
	if range_manager:
		for enemy in range_manager.get_all_enemies():
			if enemy.enemy_moved.is_connected(_on_enemy_moved):
				enemy.enemy_moved.disconnect(_on_enemy_moved)

	super()

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_enemy_spawned(enemy: Enemy) -> void:
	_connect_enemy(enemy)


func _on_enemy_moved(enemy: Enemy, old_range: int, new_range: int) -> void:
	# Only care about pushes (enemy moving away from player = increasing range).
	if new_range <= old_range:
		return

	if not range_manager:
		push_warning("NewtonsCradle: no range_manager set — was setup() called?")
		return

	var damage := _calculate_damage()
	if damage <= 0:
		return

	# Every range slot the pushed enemy swept through or came to rest in.
	for r in range(old_range + 1, new_range + 1):
		for target in range_manager.get_enemies_at_range(r):
			# Don't damage the ball that's doing the pushing.
			if target == enemy:
				continue
			if not target.is_alive():
				continue
			target.take_damgage(damage)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _connect_enemy(enemy: Enemy) -> void:
	if not enemy.enemy_moved.is_connected(_on_enemy_moved):
		enemy.enemy_moved.connect(_on_enemy_moved)


func _calculate_damage() -> int:
	if damage_calculator and player:
		return damage_calculator.calculate(player)
	return 0


func get_description_with_values() -> String:
	if not damage_calculator or not player:
		return "Pushing an enemy deals damage to every enemy it passes through."
	var dmg := damage_calculator.calculate(player)
	var formula := _format_formula_display(damage_calculator.formula)
	return "Pushing an enemy deals §%d§ (%s) damage to every enemy in its path." % [dmg, formula]


func _format_formula_display(f: String) -> String:
	return f.replace("*", " x ").replace("/", " / ").replace("+", " + ").replace("-", " - ")
