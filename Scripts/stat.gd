extends Resource
class_name Stat

signal stat_modified(stat_type: STAT, new_value: int)

enum STAT {SWAG, MARBLES, GUTS, BANG, HUSTLE, MOJO}
@export var stat_type : STAT
@export var value_calc : ValueCalculator
var value : int
@export var modify_value : float = 1.0
var character : Character
var _initialised : bool = false   # true once value_calc has run for the first time

func modify_stat(amount : int):
	var modified_amount = amount * modify_value
	value += modified_amount
	stat_modified.emit(stat_type, value)

func get_value() -> int:
	# Only run the ValueCalculator on the very first call.
	# After that, `value` is the authoritative number — gym boosts etc. are preserved.
	if not _initialised and value_calc and character:
		value = value_calc.calculate(character)
		_initialised = true
	return value
