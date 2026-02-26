extends TextureRect
class_name Thingy

## Base class for all passive items (Thingies).
##
## RunManager calls setup() at the start of each combat wave and teardown()
## when the wave ends. Subclasses override these to connect / disconnect
## signals and grab references — not _ready(), which runs only once.

var player : Character
var range_manager : RangeManager


## Called by RunManager at the start of every combat wave.
## Subclasses should connect signals and initialise combat state here.
func setup(p: Character, rm: RangeManager) -> void:
	player = p
	range_manager = rm
	

## Called by RunManager when combat ends (win, loss, or map return).
## Subclasses should disconnect any signals they connected in setup().
func teardown() -> void:
	player = null
	range_manager = null


## Optional: human-readable description shown in inventory / tooltip UI.
func get_description_with_values() -> String:
	return ""
