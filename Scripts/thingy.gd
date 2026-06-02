extends Condition
class_name ThingyCondition

## Base class for conditions that replicate the behaviour of a Thingy.
##
## Lifecycle
## ---------
## Pickup (acquired mid-run from shop/reward) — ONE-TIME:
##   RunManager.add_thingy_condition appends self to special_effects, then calls
##   on_pickup(run) ONCE. Use this for permanent instant effects (grant a stat,
##   add cards). Starting passives do NOT get on_pickup — by design, starters
##   are build-definers, not one-shot buffs.
##
## Activate (run start for starters, AND on acquisition for mid-run buys):
##   RunManager calls activate(run) once per run for EVERY owned thingy. Use it
##   to connect run-level signals (card_added_to_deck, etc.) that must fire
##   between combats. deactivate() is called at run end to disconnect them.
##
## Wave start (Character.reset_for_new_wave re-applies special_effects):
##   apply_condition() runs on a fresh duplicate → adds to character.conditions
##   and calls setup() because a RangeManager is now live. Use setup()/teardown()
##   for per-combat signal listeners.
##
## Wave end (Character.reset_for_new_wave):
##   remove_condition() → teardown() to disconnect per-wave signals.

## Rarity mirrors the Thingy rarity field so the Shop can read it.
## 0 = Common  1 = Uncommon  2 = Rare
@export var rarity: int = 0

## Live reference to the RangeManager for the current wave. Null outside combat.
var range_manager : RangeManager

# ---------------------------------------------------------------------------
# Pickup — one-time effect, fired once when acquired mid-run
# ---------------------------------------------------------------------------

## Called exactly once by RunManager.add_thingy_condition the moment the thingy
## is acquired (shop/reward). Override for permanent, instant effects — e.g.
## "gain 5 Swag", "add a card". NOT called for starting passives.
func on_pickup(run) -> void:
	pass

# ---------------------------------------------------------------------------
# Run-level lifecycle — listeners that must live for the whole run
# ---------------------------------------------------------------------------

## Called once per run for EVERY owned thingy: starting passives (at run start)
## and mid-run acquisitions alike. Override to connect run-level signals (e.g.
## card_added_to_deck) that must fire between combats, not just during waves.
## Unlike on_pickup, this runs regardless of HOW the thingy was obtained.
func activate(run) -> void:
	pass

## Called once when the run ends, mirroring activate(). Override to disconnect
## anything activate() connected, so run-level listeners don't leak across runs.
func deactivate() -> void:
	pass

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
# Combat lifecycle — override in subclasses (per-wave)
# ---------------------------------------------------------------------------

## Called when combat begins (range_manager is valid).
## Connect per-combat signals and grab combat references here.
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
