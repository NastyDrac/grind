extends Resource
class_name ItemData

@export var item_name: String = ""
@export var icon: Texture2D
@export var auto_pickup: bool = false  # If true, item is collected immediately when dropped
@export var min_amount : int
@export var max_amount : int
@export_multiline var description: String = ""

# Add any additional item properties here
# Examples:
# @export var heal_amount: int = 0
# @export var gold_value: int = 0
# @export var stat_modifier: Stat
