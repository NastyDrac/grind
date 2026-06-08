extends Resource
class_name HordeEnemy

## One enemy entry in a horde, paired with its noise cost FOR THIS HORDE.
## Noise cost lives here (not on EnemyData) so the same enemy can be an
## expensive threat in one fight and cheap filler in another.

@export var enemy : EnemyData

## How much this enemy costs to spawn from the noise meter in this horde.
## Cheap enemies = 1-2, elites = 4-6, bosses = 8+.
@export var noise_cost : int = 1
