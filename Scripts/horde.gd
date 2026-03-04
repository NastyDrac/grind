extends Resource
class_name Horde

@export var recipe_name : String = "Unnamed Horde"
@export var enemies : Array[EnemyData] = []
@export_range(1, 100) var weight : int = 1

## First map column this horde can appear on (0 = first column).
@export var min_column : int = 0

## Last map column this horde can appear on (inclusive).
## Set to -1 for no upper limit.
@export var max_column : int = -1

func is_valid_for_column(col: int) -> bool:
	if col < min_column:
		return false
	if max_column >= 0 and col > max_column:
		return false
	return true
