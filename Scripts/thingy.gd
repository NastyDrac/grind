extends Condition
class_name ThingyCondition

## Base class for conditions that replicate the behaviour of a Thingy.
##
## Lifecycle
## ---------
## Purchase / first apply (outside combat):
##   run.add_thingy_condition(condition) appends self to character_data.special_effects.
##   apply_condition() is called; because no RangeManager exists yet, setup() is skipped.
##
## Wave start (Character.reset_for_new_wave re-applies special_effects):
##   apply_condition() is called with a fresh duplicate → adds to character.conditions
##   and immediately calls setup() because a RangeManager is now in the scene tree.
##
## Wave end (Character.reset_for_new_wave iterates conditions):
##   remove_condition() is called → calls teardown() to disconnect signals.
##   conditions.clear() then removes all entries from the array.

## Rarity mirrors the Thingy rarity field so the Shop can read it.
## 0 = Common  1 = Uncommon  2 = Rare
@export var rarity: int = 0

## Live reference to the RangeManager for the current wave. Null outside combat.
var range_manager : RangeManager

# ---------------------------------------------------------------------------
# Condition interface
# ---------------------------------------------------------------------------

func apply_condition(who, condition: Condition) -> void:
	entity = who

	# Avoid duplicates (reset_for_new_wave always passes a fresh duplicate,
	# but guard anyway in case apply_condition is called manually).
	if condition not in who.conditions:
		who.conditions.append(condition)

	# If a RangeManager is already live (i.e. we're mid-combat or starting a
	# wave) hook up immediately. Outside combat this will be null, which is fine
	# — setup() will be called via apply_condition on the next wave start.
	var rm = who.get_tree().get_first_node_in_group("range_manager") if who.get_tree() else null
	if rm:
		setup(who, rm)


func remove_condition(who) -> void:
	## Called by Character.reset_for_new_wave before conditions.clear().
	## Only responsible for cleanup — do NOT erase from who.conditions here.
	teardown()


# ---------------------------------------------------------------------------
# Combat lifecycle — override in subclasses
# ---------------------------------------------------------------------------

## Called when combat begins (range_manager is valid).
## Connect signals and grab any combat references here.
func setup(who, rm) -> void:
	entity = who
	range_manager = rm


## Called when combat ends.
## Disconnect every signal connected in setup().
func teardown() -> void:
	entity = null
	range_manager = null


# ---------------------------------------------------------------------------
# Description helper — base version, override if the thingy has dynamic values
# ---------------------------------------------------------------------------

func get_description_with_values() -> String:
	return description
