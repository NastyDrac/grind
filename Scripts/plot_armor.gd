extends ThingyCondition
class_name ThingyPlotArmor

## "Plot Armor" — the first hit that would kill you instead leaves you at 1 HP.
## Single use: once it saves you, it is spent for the rest of the run and never
## re-arms. The thingy stays on your sheet (so the game still considers you to
## "own" Plot Armor), it just stops working.
##
## Hooked from Character.take_hit at the lethal-damage check (see the engine
## edit). try_save() is called on each special_effects entry that has it; the
## first one that returns true cancels the death.

var spent : bool = false

## Returns true if this thingy saved the character from a lethal hit.
## Sets health to 1 and marks itself spent so it can never fire again.
func try_save(who) -> bool:
	if spent:
		return false
	spent = true
	who.health = 1
	if who.character_data:
		who.character_data.current_health = 1
	return true

func get_description_with_values() -> String:
	if spent:
		return "Plot Armor (spent). The first lethal hit left you at 1 HP."
	return "The first hit that would kill you leaves you at 1 HP instead. Once only."
