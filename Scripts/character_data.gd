extends Resource
class_name CharacterData

@export var character_name : String
@export var character_image : Texture2D
@export var max_health : ValueCalculator
var current_health : int 
@export var stats : Array[Stat]
@export var gold : int = 25
@export var special_effects : Array[Condition] = []
