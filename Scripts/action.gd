@abstract
extends Resource
class_name Action

var player : Character
var card_handler : CardHandler  # Reference to card handler for card targeting

# Targeting options
enum TargetType {
	SINGLE_ENEMY,           # Target one enemy (at any range player chooses)
	ALL_ENEMIES,            # Target all enemies regardless of range
	ALL_ENEMIES_AT_RANGE,   # Target all enemies at a specific range
	X_ENEMIES_UP_TO_RANGE,  # Target X enemies up to max range
	SELF,                   # Target the player character
	CARD_IN_HAND,           # Target a card in hand
	CARD_IN_DISCARD,        # Target a card in discard pile
	CARD_IN_DRAW,           # Target a card in draw pile
	RANDOM_CARD_IN_HAND,    # Automatically target random card in hand
	ALL_CARDS_IN_HAND       # Target all cards in hand
}
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var max_range : int = 0

## When true, this enemy-targeting action skips its own target prompt and reuses
## the target(s) chosen by the previous targeting action on the same card — even
## if their ranges differ. Use it for follow-ups like "pull the enemy in, THEN
## hit it" so the player only picks a target once. Leave false (default) for the
## first targeting action and for any action that should prompt for its own.
@export var reuse_previous_target : bool = false

## When true, the card handler waits a short, fixed beat after firing this action
## before running the next action on the card — long enough for this action's
## animation and any enemy movement it causes to play out. Set it on a pull/push
## that precedes an attack so the target finishes sliding in before the hit.
@export var resolve_before_next : bool = false

## How long (seconds) the card handler waits after this action when it must
## resolve before the next one. Tune it to cover the animation + slide: a pull
## with a projectile needs ~0.6–0.8s; bump it up if the hit still lands early.
@export var resolve_delay : float = 0.7


## Whether the card handler should wait for this action to play out before running
## the next action on the same card. Driven by code (not only the export) so a
## pull works out of the box without a .tres reimport — PushPullAction overrides
## this to true. The export stays as an extra opt-in for other action types.
func blocks_until_resolved() -> bool:
	return resolve_before_next


## Seconds to wait when blocks_until_resolved() is true. Falls back to a sane
## default if the export wasn't set.
func get_resolve_delay() -> float:
	return resolve_delay if resolve_delay > 0.0 else 0.7

# ============================================================================
# ANIMATION
# ============================================================================

enum AnimationType {
	NONE,           # No visual — damage applies instantly
	PROJECTILE,     # A projectile travels from the player to the target
	MELEE_SLASH,    # A slash effect plays on the target
	AOE_BURST,      # A burst effect plays centred on the target(s)
	BUFF,           # A glow/shimmer effect plays on the player
}

@export var animation_type: AnimationType = AnimationType.NONE

signal animation_done


## Call this from the card handler instead of execute() directly.
## It plays the configured visual, waits for it to finish, then applies damage.
func play_animation_and_execute(target) -> void:
	if animation_type != AnimationType.NONE:
		Global.request_animation.emit(self, target, animation_type)
		await animation_done
	execute(target)


# ============================================================================
# CORE INTERFACE  (implemented by subclasses)
# ============================================================================

func requires_player_target() -> bool:
	return target_type in [TargetType.SINGLE_ENEMY, TargetType.X_ENEMIES_UP_TO_RANGE, TargetType.ALL_ENEMIES_AT_RANGE]


func requires_card_target() -> bool:
	return target_type in [TargetType.CARD_IN_HAND, TargetType.CARD_IN_DISCARD, TargetType.CARD_IN_DRAW]


func is_automatic_card_action() -> bool:
	return target_type in [TargetType.RANDOM_CARD_IN_HAND, TargetType.ALL_CARDS_IN_HAND]


func get_num_targets(character: Character) -> int:
	if target_type == TargetType.SINGLE_ENEMY:
		return 1
	return 1


func execute(target) -> void:
	push_error("execute() must be implemented in %s" % get_script().resource_path)


func get_action_type() -> String:
	return "Action"


## Whether this action has a range worth showing on the card face. Range is
## meaningless for self-buffs, card-targeting, and automatic-card actions, and for
## actions with no configured range. Subclasses can override to opt out entirely
## (e.g. ShadowStrike, which closes the gap and intentionally hides its range).
func shows_range() -> bool:
	if max_range <= 0:
		return false
	if target_type == TargetType.SELF:
		return false
	if requires_card_target() or is_automatic_card_action():
		return false
	return true


## True if this action already prints its range INLINE inside its own
## get_card_text. The card renderer uses this to avoid emitting a second range
## line for the same value. Only AttackAction does this today; everything else
## defers to the card's single shared range line, which is what lets an
## apply-condition card finally show a range without doubling up when an attack
## on the same card already shows one.
func displays_range_inline() -> bool:
	return false


func get_description_with_values(character) -> String:
	if not character:
		return ""
	return ""


## Text shown in the CARD BODY: clean, computed values, no formula breakdown.
## Defaults to the legacy description so un-converted actions keep working.
func get_card_text(character) -> String:
	return get_description_with_values(character)


## Plain-text breakdown shown in the card's HOVER TOOLTIP: the formula behind a
## value, keyword-condition explanations, etc. Empty by default.
func get_tooltip_text(character) -> String:
	return ""


## Card-body value formatter. Green when the value comes from a real formula
## (a calculation), white when it's a plain integer. Pass the calculator's
## `formula`; omit it for hard-coded literals (e.g. range).
func _cv(value, formula: String = "") -> String:
	if formula != "" and not formula.is_valid_int():
		return "§%s§" % str(value)   # calculation -> green
	return "‡%s‡" % str(value)       # literal -> white


## A "<value> <label> = <formula>" tooltip line, or "" when the value is a plain
## literal (nothing to explain).
func _formula_breakdown(label: String, value: int, formula: String) -> String:
	if formula.is_valid_int():
		return ""
	return "%d %s = %s" % [value, label, _format_formula_display(formula)]


# ============================================================================
# HELPERS
# ============================================================================

func _get_stat_value(character: Character, stat_type: Stat.STAT) -> int:
	for stat in character.stats:
		if stat.stat_type == stat_type:
			return stat.value
	return 0


func _format_formula_display(formula: String) -> String:
	var display = formula
	display = display.replace("*", " x ")
	display = display.replace("/", " / ")
	display = display.replace("+", " + ")
	display = display.replace("-", " - ")
	return display
