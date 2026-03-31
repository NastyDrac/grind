extends ThingyCondition
class_name BroomOfReform


@export var damage_calculator: ValueCalculator

# -- Combat lifecycle ----------------------------------------------------------

func setup(who, rm) -> void:
	super(who, rm)
	# Connect to enemies that spawn mid-combat.
	Global.item_picked_up.connect(fire)


func fire(item : Item):
	var all_enemies := range_manager.get_all_enemies()
	
	var target : Enemy = all_enemies.pick_random()
	target.take_damgage(damage_calculator.calculate(entity))
	


func get_description_with_values() -> String:
	if not damage_calculator or not entity:
		return "Picking up an item damages a random enemy."
	var dmg := damage_calculator.calculate(entity)
	var formula := _format_formula_display(damage_calculator.formula)
	return "Picking up an item deals %s (%s) damage to a random enemy." % [dmg,formula]


func _format_formula_display(f: String) -> String:
	return f.replace("*", " x ").replace("/", " / ").replace("+", " + ").replace("-", " - ")
