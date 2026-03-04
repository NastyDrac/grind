extends Resource
class_name HordePool

@export var recipes : Array[Horde] = []

## Picks a random Horde valid for the given map column.
## If nothing matches the column, falls back to all recipes with a warning.
func pick_random(rng: RandomNumberGenerator, column: int = 0) -> Horde:
	if recipes.is_empty():
		return null

	var candidates : Array[Horde] = []
	for r in recipes:
		if r.is_valid_for_column(column):
			candidates.append(r)

	if candidates.is_empty():
		push_warning("HordePool: no horde valid for column %d, ignoring column filter." % column)
		candidates.assign(recipes)

	var total := 0
	for r in candidates:
		total += r.weight

	if total == 0:
		return candidates[rng.randi() % candidates.size()]

	var roll  := rng.randi_range(0, total - 1)
	var accum := 0
	for r in candidates:
		accum += r.weight
		if roll < accum:
			return r

	return candidates[-1]
