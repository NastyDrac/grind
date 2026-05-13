extends Resource
class_name EnemyData


@export var enemy_name : String = "Enemy"
@export var texture : Texture2D
@export var min_health  :int = 9
@export var max_health : int = 11
@export var damage : int = 1
@export var move_speed : int = 1
@export var attack_range : int = 1
@export var conditions : Array[Condition] = []
## Optional movement pattern. If unset, the enemy uses default advance-or-attack behavior.
@export var move_pattern: MovePattern

# How much this enemy costs to spawn from the noise meter.
# Cheap enemies (goblins etc.) = 1-2, elites = 4-6, bosses = 8+
@export var noise_cost: int = 1

# Mark this enemy as an Elite. An Elite can only spawn once per combat.
# When it spawns the win condition switches to DefeatSingleEnemy targeting it,
# the progress bar is hidden, and a new announcement fires.
@export var is_elite: bool = false

## Override in a subclass to define custom per-turn movement behaviour.
## Return true if the subclass handled movement — Enemy will skip its default logic.
## Return false (default) to use Enemy's standard advance-or-attack behaviour.
func override_movement(enemy) -> bool:
	return false
