extends ThingyCondition
class_name BroomOfReform


@export var damage_calculator: ValueCalculator

# -- Combat lifecycle ----------------------------------------------------------

func setup(who, rm) -> void:
	super(who, rm)
	# Connect to item pickups for this wave. Guard against double-connecting:
	# setup() runs again every wave and Global is a persistent autoload, so a
	# stale connection could still be live.
	if not Global.item_picked_up.is_connected(fire):
		Global.item_picked_up.connect(fire)


func teardown() -> void:
	# Disconnect the per-wave listener before the base clears our references.
	if Global.item_picked_up.is_connected(fire):
		Global.item_picked_up.disconnect(fire)
	super()


func fire(item : Item):
	if not range_manager:
		return
	var all_enemies := range_manager.get_all_enemies()
	if all_enemies.is_empty():
		return
	var target : Enemy = all_enemies.pick_random()
	if target:
		target.take_damgage(damage_calculator.calculate(entity))


func get_description_with_values() -> String:
	if not damage_calculator or not entity:
		return "Picking up an item damages a random enemy."
	var dmg := damage_calculator.calculate(entity)
	var formula := _format_formula_display(damage_calculator.formula)
	return "Picking up an item deals %s (%s) damage to a random enemy." % [dmg, formula]


func _format_formula_display(f: String) -> String:
	return f.replace("*", " x ").replace("/", " / ").replace("+", " + ").replace("-", " - ")
