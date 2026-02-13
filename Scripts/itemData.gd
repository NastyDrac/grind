extends Resource
class_name ItemData

@export var item_name: String = ""
@export var icon: Texture2D
@export var auto_pickup: bool = false 
@export var min_amount : int
@export var max_amount : int
@export_multiline var description: String = ""
