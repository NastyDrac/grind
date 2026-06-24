extends ThingyCondition
class_name Boomstick

## "Boomstick" — point-blank damage. Hits against enemies at close range deal
## bonus damage. ("This... is my BOOMSTICK!") Pairs with pull cards: yank them in,
## then blast them. Combat-only; AttackAction loops the player's conditions and
## calls modify_outgoing_damage on each hit, so no signal hookup is needed.

## Enemies at this range or closer take the bonus. 1 = literally point-blank.
@export var close_range : int = 1
## Flat extra damage on a qualifying hit.
@export var bonus : int = 4


func modify_outgoing_damage(damage: int, target, _action) -> int:
	if is_instance_valid(target) and target is Enemy and target.get_current_range() <= close_range:
		return damage + bonus
	return damage


## The card preview can't know which enemy it'll hit (target is null there), so it
## shows base; the bonus lands on the real point-blank hit.
func preview_outgoing_damage(damage: int, _target, _action) -> int:
	return damage


func get_description_with_values() -> String:
	return "Your attacks deal +%d damage to enemies at range %d or closer." % [bonus, close_range]
