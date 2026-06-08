extends Resource
class_name CharacterData

@export var character_name : String
@export var character_image : Texture2D
@export var max_health : ValueCalculator
var current_health : int 
@export var stats : Array[Stat]
@export var gold : int = 25
@export var special_effects : Array[Condition] = []

## This character's signature starting deck. When set, RunManager uses it for
## the run; if left empty, RunManager falls back to its own @export deck.
@export var starting_deck : Array[CardData] = []
