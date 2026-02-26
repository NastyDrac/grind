extends Resource
class_name EventData

@export var event_title: String = "Highway Stop"
@export_multiline var event_description: String = "You see a sign for a rest stop ahead."

@export var options: Array[EventOption] = []

@export var event_image: Texture2D

@export var gold_cost: int = 0
enum Exit_Type {Gym, Store, Hospital, Mystery}
@export var event_type : Exit_Type
