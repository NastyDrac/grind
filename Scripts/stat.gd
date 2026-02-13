extends Resource
class_name Stat

signal stat_modified(stat_type: STAT, new_value: int)

enum STAT {SWAG, MARBLES, GUTS, BANG, HUSTLE, MOJO}
@export var stat_type : STAT
@export var value_calc : ValueCalculator
var value : int 
@export var modify_value : float = 1.0
var character : Character
func modify_stat(amount : int):
	var modified_amount = amount * modify_value
	value += modified_amount
	
	
	stat_modified.emit(stat_type, value)
func get_value() -> int:
	if value_calc and character:
		value = value_calc.calculate(character)
		return value
	return 0
