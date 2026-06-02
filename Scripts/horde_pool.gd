extends Resource
class_name HordePool

## A HordePool now defines an entire ACT: the pool of normal fights AND the
## pool of possible bosses. The actual boss is chosen once, at map generation,
## by RunManager (see _choose_act_boss / current_boss), so it's known and fixed
## the moment the map exists.

## Normal-combat recipes for this act.
@export var recipes : Array[Horde] = []

## Possible bosses for this act. One is chosen at map generation with the
## seeded run RNG, so a given seed always yields the same boss.
@export var boss_recipes : Array[Horde] = []

## Picks a random Horde valid for the given map column.
## Hordes whose recipe_name appears in [param used_names] are skipped unless
## every column-valid option has already been used, in which case the full
## column-valid set is used so the run never soft-locks.
## If nothing matches the column at all, falls back to all recipes with a warning.
func pick_random(rng: RandomNumberGenerator, column: int = 0, used_names: Array[String] = []) -> Horde:
	if recipes.is_empty():
		return null

	var candidates : Array[Horde] = []
	for r in recipes:
		if r.is_valid_for_column(column):
			candidates.append(r)

	if candidates.is_empty():
		push_warning("HordePool: no horde valid for column %d, ignoring column filter." % column)
		candidates.assign(recipes)

	# Prefer hordes the player hasn't fought yet this run/act.
	if not used_names.is_empty():
		var fresh : Array[Horde] = []
		for r in candidates:
			if r.recipe_name not in used_names:
				fresh.append(r)
		if not fresh.is_empty():
			candidates = fresh
		else:
			push_warning("HordePool: all column-%d hordes already used -- repeating." % column)

	return _weighted_pick(rng, candidates)

## Picks one boss from boss_recipes using the seeded RNG. Returns null if no
## bosses are authored for this act (caller should surface that loudly).
func pick_boss(rng: RandomNumberGenerator) -> Horde:
	if boss_recipes.is_empty():
		return null
	return _weighted_pick(rng, boss_recipes)

## Shared weighted random selection over a candidate list (uses Horde.weight).
func _weighted_pick(rng: RandomNumberGenerator, candidates: Array[Horde]) -> Horde:
	if candidates.is_empty():
		return null

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
