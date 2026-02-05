extends Resource
class_name EventData

# Event information
@export var event_title: String = "Highway Stop"
@export_multiline var event_description: String = "You see a sign for a rest stop ahead."

# Event options
@export var options: Array[EventOption] = []

# Optional: Image or background for this event
@export var event_image: Texture2D

# Optional: Gold cost to enter this event (if any)
@export var gold_cost: int = 0

# Optional: Can be used to categorize events (mall, gas_station, rest_stop, etc.)
@export_enum("Mall", "Gas Station", "Rest Stop", "Abandoned Vehicle", "Roadblock", "Other") var event_type: String = "Other"
