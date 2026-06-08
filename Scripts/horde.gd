extends Resource
class_name Horde

@export var recipe_name : String = "Unnamed Horde"
@export var enemies : Array[EnemyData] = []

## Per-enemy spawn entries with optional noise-cost overrides for THIS horde.
## When non-empty, this replaces `enemies` as the spawn source — letting the
## same enemy type cost different noise in different fights.
@export var enemy_entries : Array[HordeEnemy] = []
@export_range(1, 100) var weight : int = 1

## First map column this horde can appear on (0 = first column).
@export var min_column : int = 0

## Last map column this horde can appear on (inclusive).
## Set to -1 for no upper limit.
@export var max_column : int = -1

## Which reward types this horde offers after it is defeated.
## Set these in the inspector per horde recipe.
@export var rewards : Array[RewardScene.REWARD_TYPE] = []

## Win condition for this specific horde combat.
@export var win_con : WinCondition

## How much noise the combat opens with. Drives the first wave of spawns.
@export var starting_noise : float = 3.0

func is_valid_for_column(col: int) -> bool:
	if col < min_column:
		return false
	if max_column >= 0 and col > max_column:
		return false
	return true

## Builds this fight's spawn pool. Uses enemy_entries when defined, otherwise the
## legacy `enemies` list. Noise costs are NOT on the enemies — see get_noise_costs.
func get_spawn_pool() -> Array[EnemyData]:
	var pool : Array[EnemyData] = []
	if not enemy_entries.is_empty():
		for entry in enemy_entries:
			if entry and entry.enemy:
				pool.append(entry.enemy)
		return pool
	pool.append_array(enemies)
	return pool

## Maps each enemy in this horde to its noise cost. Enemies from the legacy
## `enemies` list (no entry) are omitted, so range_manager treats them as cost 1.
func get_noise_costs() -> Dictionary:
	var costs : Dictionary = {}
	for entry in enemy_entries:
		if entry and entry.enemy:
			costs[entry.enemy] = entry.noise_cost
	return costs
